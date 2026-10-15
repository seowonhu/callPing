package com.callPing.callPing_API.controller.call;

import com.callPing.callPing_API.domain.Todo;
import com.callPing.callPing_API.domain.call.CallRecord;
import com.callPing.callPing_API.dto.response.call.TodoDTO;
import com.callPing.callPing_API.repository.TodoRepository;
import com.callPing.callPing_API.repository.call.CallRecordRepository;
import com.callPing.callPing_API.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.Comparator;

@RestController
@RequestMapping("/todos")
@RequiredArgsConstructor
public class TodoController {
    // 커밋용문장
    private final TodoRepository todoRepository;
    private final CallRecordRepository callRecordRepository;

    // 8-1. 사용자 전체 TODO 목록 조회 (상태 필터링 포함)
    @GetMapping
    @Transactional(readOnly = true)
    public ResponseEntity<List<TodoDTO>> getMyTodos(
            @RequestParam(required = false) String status, // 프론트 명세: 상태 필터링 옵션
            @AuthenticationPrincipal UserPrincipal userDetails) {

        List<Todo> todos = todoRepository.findByUserIdOrderByCreatedAtDesc(userDetails.getUserId());

        // status 파라미터가 들어오면 필터링해서 반환
        if (status != null && !status.isBlank()) {
            todos = todos.stream()
                    .filter(t -> status.equalsIgnoreCase(t.getStatus()))
                    .collect(Collectors.toList());
        }

        List<TodoDTO> todoDTOs = todos.stream()
                .sorted(Comparator.comparing(Todo::getId))
                .map(t -> new TodoDTO(t.getId(),
                        t.getCallRecord() != null ? t.getCallRecord().getId() : null,
                        t.getCallRecord() != null ? t.getCallRecord().getFileName() : null,
                        t.getTaskType(),
                        t.getDescription(),
                        t.getPriority(),
                        t.getStatus()))
                .collect(Collectors.toList());

        return ResponseEntity.ok(todoDTOs);
    }

    // 8-2. 수동 TODO 추가 (recordId 옵션 포함)
    @PostMapping
    @Transactional
    public ResponseEntity<TodoDTO> createTodo(
            @RequestBody Map<String, Object> request,
            @AuthenticationPrincipal UserPrincipal userDetails) {

        // 조건: 특정 통화(recordId)와 연관지을 경우
        CallRecord callRecord = null;
        if (request.containsKey("recordId") && request.get("recordId") != null) {
            Long recordId = ((Number) request.get("recordId")).longValue();
            callRecord = callRecordRepository.findById(recordId).orElse(null);
        }

        Todo newTodo = Todo.builder()
                .userId(userDetails.getUserId())
                .callRecord(callRecord)
                .taskType((String) request.getOrDefault("taskType", "MANUAL"))
                .description((String) request.getOrDefault("description", "내용 없음"))
                .priority((String) request.getOrDefault("priority", "MEDIUM"))
                .status("PENDING")
                .createdAt(OffsetDateTime.now())
                .build();

        todoRepository.save(newTodo);

        return ResponseEntity.ok(new TodoDTO(
                newTodo.getId(),
                callRecord != null ? callRecord.getId() : null,
                callRecord != null ? callRecord.getFileName() : null,
                newTodo.getTaskType(),
                newTodo.getDescription(),
                newTodo.getPriority(),
                newTodo.getStatus()));
    }

    // 8-3. TODO 내용 및 상태 수정 (PATCH)
    @PatchMapping("/{todoId}")
    @Transactional
    public ResponseEntity<TodoDTO> updateTodo(
            @PathVariable Long todoId,
            @RequestBody Map<String, String> request,
            @AuthenticationPrincipal UserPrincipal userDetails) {

        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new IllegalArgumentException("해당 할 일을 찾을 수 없습니다."));

        // Entity 편의 메서드 사용
        todo.updateTodo(
                request.get("status"),
                request.get("description"),
                request.get("priority")
        );

        return ResponseEntity.ok(new TodoDTO(
                todo.getId(),
                todo.getCallRecord() != null ? todo.getCallRecord().getId() : null,
                todo.getCallRecord() != null ? todo.getCallRecord().getFileName() : null,
                todo.getTaskType(),
                todo.getDescription(),
                todo.getPriority(),
                todo.getStatus()));
    }

    // 8-4. TODO 삭제 (DELETE)
    @DeleteMapping("/{todoId}")
    @Transactional
    public ResponseEntity<Map<String, Object>> deleteTodo(
            @PathVariable Long todoId,
            @AuthenticationPrincipal UserPrincipal userDetails) {

        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new IllegalArgumentException("해당 할 일을 찾을 수 없습니다."));

        todoRepository.delete(todo);

        return ResponseEntity.ok(Map.of(
                "todoId", todoId,
                "success", true
        ));
    }
}
