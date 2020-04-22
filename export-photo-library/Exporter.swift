//
//  Exporter.swift
//  export-photo-library
//
//  Created by Elisey Zanko on 21.04.2020.
//  Copyright © 2020 Andreas Bentele. All rights reserved.
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

import Foundation
import MediaLibrary
import Logging

extension Exporter.Error: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .destinationExists:
            return "A file or directory exists at the destination path."
        }
    }
}

class Exporter {
    enum Error {
        case destinationExists
    }

    private var logger: Logger

    private var destination: URL!

    init(using logger: Logger) {
        self.logger = logger
    }

    private func groupPath(_ group: MLMediaGroup) -> String {
        var g = group
        var path = nameOf(group)

        while let parent = g.parent {
            // Stop at root group.
            if parent.parent == nil {
                break
            }
            path = nameOf(parent) + "/" + path
            g = parent
        }

        return path
    }

    private func derivativeURL(_ object: MLMediaObject) -> URL? {
        guard let url = object.url else {
            return nil
        }
        if let originalURL = object.originalURL, url == originalURL {
            return nil
        }
        return url
    }

    private func objectName(_ object: MLMediaObject) -> String {
        // If there's no name return object identifier.
        guard let name = object.name else {
            return object.identifier
        }
        // Otherwise, return name without extension.
        return URL.init(fileURLWithPath: name)
            .deletingPathExtension()
            .lastPathComponent
    }

    private func linkTargetURL(
        for object: MLMediaObject,
        from groupPath: String,
        with url: URL,
        suffix: String
    ) -> URL {
        var linkURL = URL.init(
            fileURLWithPath: groupPath,
            relativeTo: destination
        )

        linkURL.appendPathComponent(objectName(object) + suffix)
        // Prefer extension from the object URL rather than its name.
        // So that the link target extenstion is similar to the link source extension.
        linkURL.appendPathExtension(url.pathExtension)

        return linkURL
    }

    private func linkSourceURL(relativeTo: String, for objectID: String, with url: URL) -> URL {
        var linkURL = URL.init(
            fileURLWithPath: relativeTo,
            relativeTo: destination
        )

        // To avoid having too many files in a single directory
        // prefix resulting URL with the first character of the object identifier.
        let prefix = String(objectID[objectID.startIndex])
        linkURL.appendPathComponent(prefix)
        linkURL.appendPathComponent(objectID)
        linkURL.appendPathExtension(url.pathExtension)

        return linkURL
    }

    private func copy(at source: URL, to destination: URL) throws {
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        // Create missing directories and try again.
        } catch CocoaError.fileNoSuchFile {
            let dir = destination.deletingLastPathComponent()
            logger.debug("Copy: \(dir.absoluteURL.path) does not exist.")

            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.debug("Copy: \(dir.absoluteURL.path) created.")
            try FileManager.default.copyItem(at: source, to: destination)
        // It's OK if the file already exists.
        // We assume that it was already copied.
        // Many media objects can refer to a single file.
        } catch CocoaError.fileWriteFileExists {
            logger.debug("Copy: \(destination.absoluteURL.path) already exists.")
            return
        } catch CocoaError.fileReadNoSuchFile {
            logger.warning("Copy: \(destination.absoluteURL.path) does not exist.")
            return
        }
        logger.debug("Copy: \(source.absoluteURL.path) -> \(destination.absoluteURL.path)")
    }

    private func altLinkTarget(_ url: URL) -> URL {
        let ext = url.pathExtension
        var altURL = url.deletingPathExtension()
        let altPath = altURL.lastPathComponent + "-" + UUID().uuidString

        altURL.deleteLastPathComponent()
        altURL.appendPathComponent(altPath)
        altURL.appendPathExtension(ext)

        return altURL
    }

    private func link(target: URL, source: URL) throws {
        do {
            try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
        // Create missing directories and try again.
        } catch CocoaError.fileNoSuchFile {
            let dir = target.deletingLastPathComponent()
            logger.debug("Link: \(dir.absoluteURL.path) does not exist.")

            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.debug("Link: \(dir.absoluteURL.path) created.")
            try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
        // If the link already exists, get an alternative target URL and try again.
        // We do it because we prefer media object name in a link target URL and there's no
        // guatantee that the name is unique.
        } catch CocoaError.fileWriteFileExists {
            logger.debug("Link: \(target.absoluteURL.path) already exists.")

            let altTarget = altLinkTarget(target)
            try FileManager.default.createSymbolicLink(at: altTarget, withDestinationURL: source)
        }
        logger.debug("Link: \(source.absoluteURL.path) -> \(target.absoluteURL.path)")
    }

    private func exportObject(_ object: MLMediaObject, from groupPath: String) throws {
        if let url = object.originalURL {
            // Copy the original file.
            // Copy destination will be the link source URL.
            let sourceURL = linkSourceURL(
                relativeTo: "Originals",
                for: object.identifier,
                with: url
            )
            try copy(at: url, to: sourceURL)

            // Determine link target URL and create a link.
            let targetURL = linkTargetURL(
                for: object,
                from: groupPath,
                with: url,
                suffix: ""
            )
            try link(target: targetURL, source: sourceURL)
        }
        if let url = derivativeURL(object) {
            // Copy the derivative file.
            // Copy destination will be the link source URL.
            let sourceURL = linkSourceURL(
                relativeTo: "Derivatives",
                for: object.identifier,
                with: url
            )
            try copy(at: url, to: sourceURL)

            // Determine link target URL and create a link.
            let targetURL = linkTargetURL(
                for: object,
                from: groupPath,
                with: url,
                suffix: "-Derivative"
            )
            try link(target: targetURL, source: sourceURL)
        }
    }

    private func exportGroup(_ group: MLMediaGroup) throws {
        let name = "\"\(nameOf(group))\""

        // Recursively export child groups if there are any.
        if let childs = group.childGroups {
            for c in childs {
                try exportGroup(c)
            }
            if !childs.isEmpty {
                return
            }
        } else {
            logger.warning("No chlid groups in \(name)")
        }

        // Otherwise, export all objects of the group.
        if let objects = group.mediaObjects {
            let path = groupPath(group)
            for o in objects {
                try exportObject(o, from: path)
            }
        } else {
            logger.warning("No media objects in \(name)")
        }
    }

    func export(from group: MLMediaGroup, to destination: String) throws {
        if FileManager.default.fileExists(atPath: destination, isDirectory: nil) {
            throw Error.destinationExists
        }

        self.destination = URL.init(
            fileURLWithPath: destination,
            isDirectory: true
        )
        try exportGroup(group)
    }

}
