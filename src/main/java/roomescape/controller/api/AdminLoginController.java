package roomescape.controller.api;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import roomescape.annotation.LoginAdmin;
import roomescape.domain.admin.Admin;
import roomescape.dto.auth.info.LoginAdminInfo;
import roomescape.dto.auth.request.LoginRequest;
import roomescape.dto.auth.response.LoginCheckResponse;
import roomescape.service.LoginService;

@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/admin/login")
public class AdminLoginController {

    private final LoginService loginService;

    @PostMapping
    public ResponseEntity<Void> login(@Valid @RequestBody final LoginRequest request) {
        log.info("관리자 로그인 요청: email={}", request.email());
        String token = loginService.createAdminToken(request);

        ResponseCookie cookie = ResponseCookie.from("token", token)
                .httpOnly(true)
                .path("/")
                .build();

        log.info("관리자 로그인 완료: email={}", request.email());
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, cookie.toString())
                .build();
    }

    @GetMapping("/check")
    public ResponseEntity<LoginCheckResponse> checkLogin(@LoginAdmin final LoginAdminInfo info) {
        log.info("관리자 로그인 확인 요청: adminId={}", info.id());
        Admin admin = loginService.findByAdminId(info.id());

        LoginCheckResponse response = new LoginCheckResponse(admin.name());

        log.debug("관리자 로그인 확인 완료: adminName={}", admin.name());
        return ResponseEntity.ok()
                .body(response);
    }
}
