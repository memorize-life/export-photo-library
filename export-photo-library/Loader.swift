//
//  Loader.swift
//  export-photo-library
//
//  Created by Elisey Zanko on 08.04.2020.
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

import Foundation
import MediaLibrary
import Logging

extension Loader.Error: LocalizedError {
    var errorDescription: String? {
        switch kind {
        case .mediaSourcesLoadFailure:
            return "Failed to load media sources of \(objectName)."
        case .rootMediaGroupLoadFailure:
            return "Failed to load root media group of \(objectName)."
        case .mediaObjectsLoadFailure:
            return "Failed to load media objects of \(objectName)."
        case .loopRunFailure:
            return "Photo loading loop could not be started."
        case .photosNotFound:
            return "No photos found in \(objectName)."
        }
    }
}

class Loader: NSObject {
    struct Error {
        enum Kind {
            case mediaSourcesLoadFailure
            case rootMediaGroupLoadFailure
            case mediaObjectsLoadFailure
            case loopRunFailure
            case photosNotFound
        }

        let kind: Kind
        let objectName: String
    }

    private struct LibraryKeys {
        static let mediaSources = "mediaSources"
        static let rootMediaGroup = "rootMediaGroup"
        static let mediaObjects = "mediaObjects"
    }

    private let library = MLMediaLibrary(options: [
        MLMediaLoadSourceTypesKey: MLMediaSourceType.image.rawValue,
        MLMediaLoadIncludeSourcesKey: [MLMediaSourcePhotosIdentifier],
    ])

    private var logger: Logger

    private var mustStop = false
    private var groupsToLoad: UInt = 0
    private var error: Error?

    private var source: MLMediaSource!
    private var root: MLMediaGroup!

    init(using logger: Logger) {
        self.logger = logger
    }

    func load() throws -> MLMediaGroup {
        logger.debug("Observe media sources of \(library)")
        library.addObserver(
            self,
            forKeyPath: LibraryKeys.mediaSources,
            options: NSKeyValueObservingOptions.new,
            context: nil
        )
        // Returns nil the first time, beginning an asynchronous load of the media sources.
        if library.mediaSources != nil {
            throw Error(kind: .mediaSourcesLoadFailure, objectName: "\(library)")
        }

        while !mustStop {
            if !RunLoop.current.run(mode: RunLoop.Mode.default, before: .distantFuture) {
                throw Error(kind: .loopRunFailure, objectName: "")
            }
        }

        if let error = self.error {
            throw error
        }
        return root
    }

    private func stop(with error: Error? = nil) {
        self.error = error
        mustStop = true
    }

    private func loadSource() {
        guard let sources = library.mediaSources else {
            return stop(with: Error(kind: .mediaSourcesLoadFailure, objectName: "\(library)"))
        }
        guard let source = sources[MLMediaSourcePhotosIdentifier] else {
            return stop(with: Error(kind: .photosNotFound, objectName: "\(library)"))
        }

        self.source = source

        logger.debug("Done observing media sources of \(library)")
        library.removeObserver(self, forKeyPath: LibraryKeys.mediaSources)

        let sourceName = "\"\(source.mediaSourceIdentifier)\""
        logger.debug("Observe root media group of \(sourceName)")
        source.addObserver(
            self,
            forKeyPath: LibraryKeys.rootMediaGroup,
            options: NSKeyValueObservingOptions.new,
            context: nil
        )
        // Returns nil the first time, beginning an asynchronous load of the root media group.
        if source.rootMediaGroup != nil {
            return stop(with: Error(kind: .rootMediaGroupLoadFailure, objectName: sourceName))
        }
    }

    private func loadObjects(for group: MLMediaGroup) {
        groupsToLoad += 1

        let groupName = "\"\(nameOf(group))\""
        logger.debug("Observe media objects of \(groupName)")
        group.addObserver(
            self,
            forKeyPath: LibraryKeys.mediaObjects,
            options: NSKeyValueObservingOptions.new,
            context: nil
        )
        // Returns nil the first time, beginning an asynchronous load of the media objects.
        if group.mediaObjects != nil {
            return stop(with: Error(kind: .mediaObjectsLoadFailure, objectName: groupName))
        }

        // Recursively load childs of the group.
        if let childs = group.childGroups {
            for child in childs {
                loadObjects(for: child)
            }
        }
    }

    private func loadRootGroup() {
        let sourceName = "\"\(source.mediaSourceIdentifier)\""
        guard let root = source.rootMediaGroup else {
            return stop(with: Error(kind: .rootMediaGroupLoadFailure, objectName: sourceName))
        }

        self.root = root

        logger.debug("Done observing root media group of \(sourceName)")
        source.removeObserver(self, forKeyPath: LibraryKeys.rootMediaGroup)

        loadObjects(for: root)
    }

    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == LibraryKeys.mediaSources {
            return loadSource()
        }
        if keyPath == LibraryKeys.rootMediaGroup {
            return loadRootGroup()
        }
        if keyPath == LibraryKeys.mediaObjects {
            let group = object as! MLMediaGroup

            logger.debug("Done observing media objects of \"\(nameOf(group))\"")
            group.removeObserver(self, forKeyPath: LibraryKeys.mediaObjects)

            groupsToLoad -= 1
            if groupsToLoad == 0 {
                return stop()
            }
        }
    }
}
