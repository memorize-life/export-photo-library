//
//  main.swift
//  export-photo-library
//
//  Created by Elisey Zanko on 07.04.2020.
//  Copyright © 2020 Elisey Zanko. All rights reserved.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import ArgumentParser
import Logging

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export-photo-library",
        abstract: "Export user's photo library preserving metadata."
    )

    @Argument()
    var destination: String

    func run() throws {
        var logger = Logger(label: "life.memorize.export-photo-library")
        logger.logLevel = Logger.Level.debug

        let loader = Loader(using: logger)
        let root = try loader.load()

        let exporter = Exporter(using: logger)
        try exporter.export(from: root, to: destination)
    }
}

ExportCommand.main()
