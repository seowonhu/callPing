package com.callPing.callPing_API.client.rag;

import com.callPing.callPing_API.exception.ApiException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

@Slf4j
@Component
@RequiredArgsConstructor
public class RagClient {

    private final WebClient ragWebClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public String query(String question) {
        RagQueryRequest request = new RagQueryRequest(question);

        try {
            RagQueryResponse response = ragWebClient.post()
                    .uri("/rag/query")
                    .bodyValue(request)
                    .retrieve()
                    .bodyToMono(RagQueryResponse.class)
                    .block();

            if (response == null) {
                throw new ApiException(503, "CHAT_ERR_RAG_EMPTY_RESPONSE", "RAG 서버 응답이 비어있습니다.");
            }

            return response.answer();

        } catch (WebClientResponseException e) {
            String message = extractDetailMessage(e);
            throw new ApiException(e.getStatusCode().value(), "CHAT_ERR_RAG_SERVER", message);
        } catch (Exception e) {
            log.error("RAG 서버 호출 실패", e);
            throw new ApiException(503, "CHAT_ERR_RAG_UNAVAILABLE", "RAG 서버에 연결할 수 없습니다.");
        }
    }

    private String extractDetailMessage(WebClientResponseException e) {
        String body = e.getResponseBodyAsString();
        if (body.isBlank()) {
            return "RAG 서버 오류";
        }
        try {
            JsonNode node = objectMapper.readTree(body);
            if (node.has("detail")) {
                return node.get("detail").asText();
            }
            return body;
        } catch (Exception parseEx) {
            return body;
        }
    }

    record RagQueryRequest(String question) {}
    record RagQueryResponse(String answer) {}
}