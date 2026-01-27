//
//  TestSMTPConfig.swift
//  feather-mail-driver-smtp
//
//  Created by Binary Birds on 2026. 01. 26..
//

struct TestSMTPConfig {
    let host: String
    let user: String
    let pass: String
    let from: String
    let to: String

    static func load() -> TestSMTPConfig {
        // NOTE: This test config is intentionally hardcoded and does not read
        // environment variables or .env files. These tests are integration
        // tests; fill in the values below locally when you want to run them.
        // Keep secrets out of source control.
        return TestSMTPConfig(
            host: "",
            user: "",
            pass: "",
            from: "",
            to: ""
        )
    }

    var isComplete: Bool {
        !host.isEmpty
            || !user.isEmpty
            || !pass.isEmpty
            || !from.isEmpty
            || !to.isEmpty
    }
}
