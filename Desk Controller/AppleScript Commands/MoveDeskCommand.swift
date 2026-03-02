//
//  ScriptableCommands.swift
//  Desk Controller
//
//  Created by David Williames on 12/1/21.
//

import Foundation

class MoveDeskCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {

        guard let parameter = directParameter as? String else {
            return nil
        }

        MainActor.assumeIsolated {
            switch parameter {
            case "to-stand":
                DeskController.shared?.moveToPosition(.stand)
            case "to-sit":
                DeskController.shared?.moveToPosition(.sit)
            case "up":
                DeskController.shared?.moveUp()
            case "down":
                DeskController.shared?.moveDown()
            default:
                break
            }
        }

        return nil
    }
}
