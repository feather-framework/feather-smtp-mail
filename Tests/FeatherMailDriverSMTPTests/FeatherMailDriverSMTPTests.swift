//
//  FeatherMailDriverSMTPTests.swift
//  feather-mail-driver-smtp
//
//  Created by Tibor Bodecs on 2023. 01. 16..
//

import NIO
import Logging
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
import NIOSMTP
@testable import FeatherMail
@testable import FeatherMailDriverSMTP

@Suite
struct FeatherMailDriverSMTPTests {

    // MARK: - Environment configuration

    private let config = TestSMTPConfig.load()

    private func makeDriver() -> SMTPMailDriver {
        let config = Configuration(
            hostname: config.host,
            signInMethod: config.user.isEmpty
                ? .anonymous
                : .credentials(username: config.user, password: config.pass)
        )

        return SMTPMailDriver(configuration: config)
    }

    // MARK: - Tests

    @Test
    func sendPlainTextMail() async throws {
        if !config.isComplete { return }
        let driver = makeDriver()

        let mail = Mail(
            from: .init(config.from),
            to: [.init(config.to)],
            subject: "SMTP plain text test",
            body: .plainText("Hello from Feather SMTP driver.")
        )

        try await driver.send(mail)
        try await driver.shutdown()
    }

    @Test
    func sendHTMLMail() async throws {
        if !config.isComplete { return }
        let driver = makeDriver()

        let mail = Mail(
            from: .init(config.from),
            to: [.init(config.to)],
            subject: "SMTP HTML test",
            body: .html("<p>Hello <strong>SMTP</strong></p>")
        )

        try await driver.send(mail)
        try await driver.shutdown()
    }

    @Test
    func sendMailWithAttachment() async throws {
        if !config.isComplete { return }
        let driver = makeDriver()

        let data = Array("Hello attachment".utf8)

        let mail = Mail(
            from: .init(config.from),
            to: [.init(config.to)],
            subject: "SMTP Attachment Test",
            body: .plainText("This mail contains an attachment."),
            attachments: [
                .init(
                    name: "test.txt",
                    contentType: "text/plain",
                    data: data
                )
            ]
        )

        try await driver.send(mail)
        try await driver.shutdown()
    }

    @Test
    func invalidMailFailsBeforeSending() async {
        if !config.isComplete { return }
        let driver = makeDriver()

        let mail = Mail(
            from: .init(" "),
            to: [.init(config.to)],
            subject: "Invalid sender",
            body: .plainText("This should not be sent.")
        )

        await #expect(throws: MailError.validation(.invalidSender)) {
            try await driver.send(mail)
        }

        try? await driver.shutdown()
    }

}
