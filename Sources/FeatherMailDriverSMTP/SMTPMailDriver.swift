//
//  SMTPMailDriver.swift
//  feather-mail-driver-smtp
//
//  Created by gerp83 on 2026. 01. 17.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
import FeatherMail
import NIOSMTP

/// A mail driver implementation backed by SMTP.
///
/// `SMTPMailDriver` is intended to be initialized once during server startup
/// and reused for the lifetime of the application. It validates mails,
/// encodes them into SMTP-compatible DATA payloads, and delivers them using
/// an internally managed SMTP client.
///
/// The driver owns the underlying SMTP client and is responsible for
/// shutting it down when the server stops.
public struct SMTPMailDriver: MailClient, Sendable {

    /// Validator applied before encoding and delivery.
    private let validator: MailValidator

    /// Underlying SMTP client responsible for protocol communication.
    private let client: SMTPClient

    /// Logger used for SMTP operations.
    private let logger: Logger

    /// Creates a new SMTP mail driver.
    ///
    /// This initializer should typically be called during server startup.
    /// The resulting driver instance is expected to live for the entire
    /// lifetime of the application.
    ///
    /// - Parameters:
    ///   - configuration: SMTP client configuration.
    ///   - validator: Validator applied before delivery.
    ///   - logger: Logger used for SMTP request and transport logging.
    init(
        configuration: Configuration,
        validator: MailValidator = BasicMailValidator(),
        logger: Logger = .init(label: "feather.mail.smtp")
    ) {
        self.validator = validator
        self.client = SMTPClient(configuration: configuration, logger: logger)
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
            try await client.send(email)
        }
        catch {
            throw mapSMTPError(error)
        }
    }

    /// Shuts down the underlying SMTP client.
    ///
    /// This method must be called when the server is stopping to release
    /// network resources and event loops owned by the driver.
    public func shutdown() async throws {
        try await client.shutdown()
    }

    /// Validates a mail using the configured validator.
    ///
    /// - Parameter mail: The mail to validate.
    /// - Throws: `MailValidationError` when validation fails.
    public func validate(_ mail: Mail) async throws(MailValidationError) {
        try await validator.validate(mail)
    }

    private func mapSMTPError(_ error: Error) -> MailError {
        return .unknown(error)
    }
}
