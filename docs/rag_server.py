"""
RAG 챗봇 API 서버 (FastAPI)
- Spring Boot(ChatServiceImpl)에서 이 서버의 /rag/query 를 내부 호출합니다.
- 외부에는 노출하지 말고, EC2 내부(localhost 또는 내부망)에서만 접근 가능하도록 구성하세요.
- uvicorn rag_server:app --host 0.0.0.0 --port 8000로 실행
- ngrok url
- ngrok http --url=moocher-sterilize-chatty.ngrok-free.dev 8000
"""

import json
import os
import logging
import re

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
from google import genai
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_chroma import Chroma

# ================================================================
# 설정 & 초기화 (서버 시작 시 1회만 실행됨)
# ================================================================

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("rag-server")

load_dotenv()

LEVEL_THRESHOLDS = {
    1: 0.45,  # source+category+sub_category
    2: 0.42,
    3: 0.40,
    4: 0.35,  # 필터 없음 (기존 유지)
}

MAX_LEN = 500
TOP_K = 3
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")

# EC2(리눅스, GPU 없음)에서는 반드시 cpu 로 설정하세요.
# NVIDIA GPU가 붙은 인스턴스(g4dn 등)라면 cuda 로 변경 가능합니다.
EMBEDDING_DEVICE = os.getenv("EMBEDDING_DEVICE", "cpu")

CHROMA_DB_PATH = os.getenv("CHROMA_DB_PATH", "./chroma_db")

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise RuntimeError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")

client = genai.Client(api_key=api_key)

logger.info(f"임베딩 모델 로드 중... (device={EMBEDDING_DEVICE})")
embeddings = HuggingFaceEmbeddings(
    model_name="BAAI/bge-m3",
    model_kwargs={"device": EMBEDDING_DEVICE},
    encode_kwargs={"normalize_embeddings": True},
)

logger.info(f"Chroma DB 로드 중... (path={CHROMA_DB_PATH})")
vectorstore = Chroma(persist_directory=CHROMA_DB_PATH, embedding_function=embeddings)

metadatas = vectorstore.get(include=["metadatas"])["metadatas"]
source_list = list(set([m["source"] for m in metadatas if "source" in m]))
logger.info(f"로드된 source 목록: {source_list}")

# context 정제
def clean_answer(raw_answer: str) -> str:
    text = raw_answer.strip()
    text = re.sub(r"^\s*\[AI\s*최종\s*답변\]\s*:?\s*", "", text)
    text = re.sub(r"^\s*\[답변\]\s*:?\s*", "", text)
    return text.strip()

# ================================================================
# 계층적 필터링 검색 (기존 로직 그대로)
# ================================================================

def hierarchical_retrieval(query: str, metadata_filter: dict | None, k: int = TOP_K):
    if not metadata_filter:
        logger.info(f"추출된 필터 없음 → 전체 구역 자연어 유사도 검색 (query='{query}')")
        return vectorstore.similarity_search(query, k=k)

    source = metadata_filter.get("source")
    category = metadata_filter.get("category")
    sub_category = metadata_filter.get("sub_category")

    levels = []
    if source and category and sub_category:
        levels.append({"$and": [
            {"source": {"$eq": source}},
            {"category": {"$eq": category}},
            {"sub_category": {"$eq": sub_category}},
        ]})
    if source and category:
        levels.append({"$and": [{"source": {"$eq": source}}, {"category": {"$eq": category}}]})
    if source:
        levels.append({"source": {"$eq": source}})
    levels.append(None)

    best_docs = []
    best_score = float("inf")

    for level_num, filt in enumerate(levels, start=1):
        threshold = LEVEL_THRESHOLDS[level_num]

        try:
            results = vectorstore.similarity_search_with_score(query=query, k=k, filter=filt)
            if not results:
                continue

            valid_results = [(doc, score) for doc, score in results if score < threshold]
            if not valid_results:
                continue

            current_best_score = valid_results[0][1]
            logger.info(
                f"[Level {level_num}] threshold={threshold} 매칭 {len(results)}개 중 순도 검증 통과: "
                f"{len(valid_results)}개 (최상위 점수: {current_best_score:.4f})"
            )

            if current_best_score < best_score:
                best_score = current_best_score
                best_docs = [doc for doc, score in valid_results]

            if best_score < 0.15:
                break

        except Exception as e:
            logger.error(f"[Error] Level {level_num} 검색 도중 예외 발생: {e}")

    if not best_docs:
        logger.warning("필터 구역 내 유효 점수 문서 없음 → 전체 해제 일반 검색으로 백업")
        return vectorstore.similarity_search(query, k=k)

    return best_docs


# ================================================================
# 프롬프트 (기존 로직 그대로)
# ================================================================

def build_analysis_prompt(user_input: str) -> str:
    return f"""
사용자의 질문을 분석하여 Chroma DB 검색에 사용할 '검색어(query)'와 '메타데이터 필터(filter)'를 분리해줘.
우리 DB의 메타데이터 키는 3개야: 'source', 'category', 'sub_category'
필터는 반드시 순서대로 좁혀야 해: source → category → sub_category

[중요 규칙]
- 사용자가 말 끝에 오타(예: '알려줘ㅏ', '알려쟈', '궁금해ㅛ', '알려줭' 등)를 내더라도 문맥을 파악해 무시해줘.
- 추출하는 'query'(검색어)에는 조사나 '알려줘', '알려쟈', '확인' 같은 서술어를 모두 제외하고, DB에서 정보를 찾기 위한 '핵심 명사(키워드)' 위주로만 깔끔하게 정제해줘.
- source 없이 category만 필터링하면 안 돼
- category 없이 sub_category만 필터링하면 안 돼
- 질문에 명확한 정보가 없는 키는 필터에서 생략해
- 아래 source 목록 중 사용자 입력과 축약어, 줄임말, 일부 일치, 의미상 동일한 경우 모두 해당 값으로 맵핑해줘
- 목록에 없는 source는 절대 사용하지마
- 질문에 명확한 기관명이나 카테고리가 없다면 filter를 null로 처리해

[DB에 존재하는 source 목록]
{source_list}

반드시 아래 예시와 같은 순수한 JSON 형식으로만 답변해. 다른 설명은 절대 하지마.
{{"query": "검색어", "filter": {{"source": "기관명", "category": "카테고리", "sub_category": "서브카테고리"}}}}
또는 {{"query": "검색어", "filter": null}}

[현재 사용자의 질문]
"{user_input}"

[분석 결과 JSON]:"""

def build_qa_prompt(user_input: str, context_text: str) -> str:
    return f"""
너는 오직 제공된 [참고자료]의 사실(Fact)만을 기반으로 답변하는 엄격한 정보 검증 전문가야.
인간적인 친절함, 인삿말, 임의의 추론이나 유추는 모두 절대 금지한다.

[동작 규칙 - 매우 중요]
1. [질문]에서 요구하는 구체적인 대상(예: 특정 기업명, 특정 상황 등)이나 정답에 대한 명확한 근거가 [참고자료]의 텍스트 안에 '문자 그대로' 존재하지 않는다면, 무관한 문서로 판단해야 해.
2. 단, 질문에 포함된 기관명/병원명/회사명은 이미 해당 기관 자료로 필터링되어 제공된 것이므로, 참고자료 본문에 그 이름이 별도로 언급되지 않았다는 이유만으로는 무관하다고 판단하지 마. (기관명 외의 나머지 조건은 규칙 1을 그대로 엄격히 적용해.)
3. [참고자료]를 바탕으로 [질문]에 대해 100% 팩트에 기반한 답변을 완전하게 도출할 수 없다면, 다른 친절한 설명이나 변명을 절대 덧붙이지 마.
4. 자료에서 명확한 정답 근거를 찾을 수 없는 경우, 주저하지 말고 무조건 아래 지정된 문장 하나만 정확하게 출력해:
   "죄송합니다. 제공된 문서 내에서 해당 질문에 대한 답변을 찾을 수 없습니다."

[정보가 존재할 때의 가이드]
- [참고자료]에 정답 근거가 확실하게 존재할 때만, 그 내용을 바탕으로 사용자가 읽기 쉽게 명확한 문장으로 답변해줘.
- 핵심 정답을 최우선으로 강조하여 설명하고, 공백 포함 1,000자 이내로 매끄럽게 완성해줘.

[참고자료]
{context_text}

[질문]
{user_input}

[AI 최종 답변]:"""

def call_gemini(prompt: str) -> str:
    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config={"temperature": 0},
        )
        return clean_answer(response.text)
    except Exception as e:
        error_str = str(e)
        logger.error(f"Gemini 호출 실패: {error_str}")
        if "429" in error_str:
            if "PerDay" in error_str or "per_day" in error_str.lower():
                raise HTTPException(status_code=429, detail="일일 요청 한도를 초과했습니다. 내일 오전 9시 이후 다시 이용해주세요.")
            raise HTTPException(status_code=429, detail="잠시 요청이 많습니다. 잠시 후 다시 시도해주세요.")
        if "503" in error_str:
            raise HTTPException(status_code=503, detail="서버가 혼잡합니다. 잠시 후 다시 시도해주세요.")
        raise HTTPException(status_code=500, detail="오류가 발생했습니다. 잠시 후 다시 시도해주세요.")


# ================================================================
# FastAPI 앱 & 엔드포인트
# ================================================================

app = FastAPI(title="RAG Chat Server")


class QueryRequest(BaseModel):
    question: str


class QueryResponse(BaseModel):
    answer: str


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/rag/query", response_model=QueryResponse)
def query(request: QueryRequest):
    user_input = request.question.strip()

    if not user_input:
        raise HTTPException(status_code=400, detail="질문이 비어있습니다.")

    if len(user_input) > MAX_LEN:
        raise HTTPException(
            status_code=400,
            detail=f"입력 가능한 글자수를 초과했습니다. ({len(user_input)}/{MAX_LEN}자)",
        )

    # STEP 1. 메타데이터 파싱
    analysis_text = call_gemini(build_analysis_prompt(user_input))
    try:
        parsed_analysis = json.loads(analysis_text.strip().replace("```json", "").replace("```", ""))
        search_query = parsed_analysis.get("query", user_input)
        search_filter = parsed_analysis.get("filter", None)
    except Exception:
        search_query = user_input
        search_filter = None


    if search_filter:
        search_filter = {k: v for k, v in search_filter.items() if v is not None}
        if not search_filter:
            search_filter = None


    # STEP 2. 검색
    search_results = hierarchical_retrieval(search_query, search_filter, k=TOP_K)
    context_text = "\n\n".join(
        [f"[자료 {i + 1}]\n{doc.page_content}" for i, doc in enumerate(search_results)]
    )


    # STEP 3. 최종 답변 생성
    answer = call_gemini(build_qa_prompt(user_input, context_text))

    return QueryResponse(answer=answer)
