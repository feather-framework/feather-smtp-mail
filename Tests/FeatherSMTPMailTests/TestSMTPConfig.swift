//
//  TestSMTPConfig.swift
//  feather-smtp-mail
//
//  Created by Binary Birds on 2026. 01. 26..
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct TestSMTPConfig {
    let host: String
    let user: String
    let pass: String
    let from: String
    let to: String

    static func load() -> TestSMTPConfig {
        // NOTE: Tests read from environment variables first and then fall back
        // to hardcoded values below.
        //
        // Environment variables (preferred):
        //   SMTP_HOST
        //   SMTP_USER
        //   SMTP_PASS
        //   SMTP_FROM
        //   SMTP_TO
        //
        // To run integration tests locally without env vars, fill in the values
        // below. Keep secrets out of source control.
        let env = ProcessInfo.processInfo.environment
        return TestSMTPConfig(
            host: env["SMTP_HOST"]!,
            user: env["SMTP_USER"]!,
            pass: env["SMTP_PASS"]!,
            from: env["SMTP_FROM"]!,
            to: env["SMTP_TO"]!
        )
    }

}
