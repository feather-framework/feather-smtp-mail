//
//  FeatherSMTPMailTests.swift
//  feather-smtp-mail
//
//  Created by Tibor Bodecs on 2023. 01. 16..
//

import NIO
import Logging
import Testing
import NIOSMTP
@testable import FeatherMail
@testable import FeatherSMTPMail

@Suite
struct FeatherSMTPMailTests {

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
        let driver = makeDriver()

        let mail = Mail(
            from: .init(" "),
            to: [.init(config.to)],
            subject: "Invalid sender",
            body: .plainText("This should not be sent.")
        )

        do {
            try await driver.send(mail)
            #expect(Bool(false))
        }
        catch {
            if case let .validation(validationError) = error,
                validationError == .invalidSender
            {
                #expect(true)
            }
            else {
                #expect(Bool(false))
            }
        }

        try? await driver.shutdown()
    }

}
