// Models.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import Foundation
import SwiftData

@Model
final class ROMEntry {
    var url: String
    var title: String
    var system: String
    var lastPlayed: Date
    var favorite: Bool

    init(url: String, title: String, system: String, lastPlayed: Date = .now, favorite: Bool = false) {
        self.url = url
        self.title = title
        self.system = system
        self.lastPlayed = lastPlayed
        self.favorite = favorite
    }
}



