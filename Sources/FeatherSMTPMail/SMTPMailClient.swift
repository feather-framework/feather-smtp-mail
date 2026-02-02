//
//  SMTPMailClient.swift
//  feather-smtp-mail
//
//  Created by gerp83 on 2026. 01. 17.
//

import Foundation
import Logging
import FeatherMail
import NIO
import NIOSMTP

/// A mail client implementation backed by SMTP.
///
/// `SMTPMailClient` is intended to be initialized once during server startup
/// and reused for the lifetime of the application. It validates mails,
/// encodes them into SMTP-compatible DATA payloads, and delivers them using
/// an internally managed SMTP client.
///
/// The client owns the underlying SMTP client and is responsible for
/// shutting it down when the server stops.
public struct SMTPMailClient: MailClient, Sendable {

    /// Validator applied before encoding and delivery.
    private let validator: MailValidator

    /// Underlying SMTP client responsible for protocol communication.
    private let smtp: NIOSMTP

    /// Raw mail encoder used to build SMTP DATA payloads.
    private let rawEncoder = RawMailEncoder()

    /// Logger used for SMTP operations.
    private let logger: Logger

    /// Creates a new SMTP mail client.
    ///
    /// This initializer should typically be called during server startup.
    /// The resulting client instance is expected to live for the entire
    /// lifetime of the application.
    ///
    /// - Parameters:
    ///   - configuration: SMTP client configuration.
    ///   - validator: Validator applied before delivery.
    ///   - eventLoopGroup: EventLoopGroup.
    ///   - logger: Logger used for SMTP request and transport logging.
    init(
        configuration: Configuration,
        validator: MailValidator = BasicMailValidator(),
        eventLoopGroup: EventLoopGroup,
        logger: Logger = .init(label: "feather.mail.smtp")
    ) {
        self.validator = validator
        self.smtp = NIOSMTP(
            eventLoopGroup: eventLoopGroup,
            configuration: configuration,
            logger: logger
        )
        self.logger = logger
    }

    /// Sends a mail using SMTP.
    ///
    /// This method performs mail validation, SMTP DATA encoding, and
    /// delivery using the internally managed SMTP client.
    ///
    /// - Parameter email: The mail to send.
    /// - Throws: `MailError` if validation, encoding, or delivery fails.
    public func send(_ email: Mail) async throws(MailError) {
        do {
            try await validate(email)
        }
        catch {
            throw .validation(error)
        }
        do {
            let raw = try rawEncoder.encode(
                email,
                dateHeader: formatDateHeader(),
                messageID: createMessageID(for: email)
            )
            let recipients = (email.to + email.cc + email.bcc).map(\.email)
            let envelope = try SMTPEnvelope(
                from: email.from.email,
                recipients: recipients,
                data: raw
            )
            try await smtp.send(envelope)
        }
        catch {
            throw mapSMTPError(error)
        }
    }

    /// Validates a mail using the configured validator.
    ///
    /// - Parameter mail: The mail to validate.
    /// - Throws: `MailValidationError` when validation fails.
    public func validate(_ mail: Mail) async throws(MailValidationError) {
        try await validator.validate(mail)
    }

    private func mapSMTPError(_ error: Error) -> MailError {
        guard let smtpError = error as? NIOSMTPError else {
            return .unknown(error)
        }

        if case let .custom(message) = smtpError {
            return .custom(message)
        }
        if case let .unknown(underlying) = smtpError {
            return .unknown(underlying)
        }
        return .unknown(smtpError)
    }

    private func formatDateHeader() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return dateFormatter.string(from: Date())
    }

    private func createMessageID(for mail: Mail) -> String {
        let time = Date().timeIntervalSince1970
        return "<\(time)\(mail.from.email.drop { $0 != "@" })>"
    }
}
