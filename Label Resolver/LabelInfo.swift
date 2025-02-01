//
//  LabelInfo.swift
//  Label Resolver
//
//  Created by Gil Burns on 1/31/25.
//

import Foundation

struct LabelInfo: Codable {
    var appCustomVersion: String
    var appName: String
    var appNewVersion: String
    var archiveName: String
    var blockingProcesses: String
    var CLIInstaller: String
    var CLIArguments: String
    var curlOptions: String
    var downloadURL: String
    var expectedTeamID: String
    var installerTool: String
    var name: String
    var packageID: String
    var pkgName: String
    var targetDir: String
    var type: String
    var updateTool: String
    var updateToolArguments: String
    var updateToolRunAsCurrentUser: String
    var versionKey: String
}

