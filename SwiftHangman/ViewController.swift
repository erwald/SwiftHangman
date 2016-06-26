//
//  ViewController.swift
//  SwiftHangman
//
//  Created by Erich Grunewald on 25/06/16.
//  Copyright © 2016 Erich Grunewald. All rights reserved.
//

import UIKit
import SnapKit
import SwiftPhoenixClient

class ViewController: UIViewController, UITextFieldDelegate {
    
    let stateLabel = UILabel()
    let guessesLabel = UILabel()
    let input = UITextField()
    
    let socket = Phoenix.Socket(domainAndPort: "localhost:4000", path: "socket", transport: "websocket")
    
    
    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up views.
        stateLabel.numberOfLines = 0
        guessesLabel.numberOfLines = 0
        guessesLabel.text = ""
        input.placeholder = "Make a guess ..."
        input.delegate = self
        
        self.view.addSubview(stateLabel)
        self.view.addSubview(guessesLabel)
        self.view.addSubview(input)
        
        // Create view constraints.
        let insets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stateLabel.snp_makeConstraints { make in
            make.top.left.right.equalTo(self.view).inset(insets)
            make.height.equalTo(80)
        }
        guessesLabel.snp_makeConstraints { make in
            make.top.equalTo(stateLabel.snp_bottom).offset(10)
            make.left.right.equalTo(self.view).inset(insets)
        }
        input.snp_makeConstraints { make in
            make.top.equalTo(guessesLabel.snp_bottom).offset(10)
            make.left.right.bottom.equalTo(self.view).inset(insets)
            make.height.equalTo(60)
        }
        
        // Bind with Phoenix channel.
        socket.join(topic: "games:1", message: Phoenix.Message(subject: "status", body: "joining")) { channel in
            let channel = channel as! Phoenix.Channel
            
            channel.on("new:guess", callback: { message in
                guard let message = message as? Phoenix.Message,
                    let resultJSON = message.message?["result"] as? SwiftPhoenixClient.JSON,
                    let letterJSON = message.message?["letter"] as? SwiftPhoenixClient.JSON,
                    let result = resultJSON.asString,
                    let letter = letterJSON.asString else {
                        return
                }
                
                // Update label by appending the string representing the guess.
                var messageForUser = ""
                switch result {
                case "invalid_entry":
                    messageForUser = "Somebody tried to guess \(letter), but that's not a letter, is it?"
                case "finished":
                    messageForUser = "Somebody tried to make a guess, but the game was already over."
                case "duplicate":
                    messageForUser = "Somebody tried to guess \(letter), but the guess had already been made."
                case "too_soon":
                    messageForUser = "Somebody tried to guess \(letter), but it was too soon after the previous guess."
                case "ok":
                    messageForUser = "Somebody guessed \(letter)."
                default:
                    messageForUser = ""
                }
                
                self.guessesLabel.text = "\(messageForUser)\n".stringByAppendingString(self.guessesLabel.text ?? "")
            })
            
            channel.on("new:state", callback: { message in
                guard let message = message as? Phoenix.Message,
                    let state = message.message?["state"] as? SwiftPhoenixClient.JSON,
                    let progress = state["progress"].asString,
                    let maxGuesses = state["max_guesses"].asInt else {
                        return
                }
                
                // Unpack arrays in an ugly way.
                var phrase : [String] = []
                for (_, v) in state["phrase"] {
                    if let letter = v.asString {
                        phrase.append(letter)
                    }
                }
                var guesses : [String] = []
                for (_, v) in state["guesses"] {
                    if let letter = v.asString {
                        guesses.append(letter)
                    }
                }
                
                // Create pretty strings and numbers.
                let phraseString = phrase.joinWithSeparator("")
                let guessesString = guesses.joinWithSeparator(", ")
                let remaining = maxGuesses - guesses.count
                
                // Update state label with string representing the new game state.
                switch progress {
                case "in_progress":
                    self.stateLabel.text = "“\(phraseString)”,\nwith guesses: \(guessesString) (\(remaining) remaining)"
                    self.input.enabled = true
                case "won":
                    self.stateLabel.text = "You won! The phrase was “\(phraseString)” and you managed it with \(remaining) guesses left in the bank!"
                    self.guessesLabel.text = ""
                    self.input.enabled = false
                case "lost":
                    self.stateLabel.text = "You lost! The phrase we were looking for was “\(phraseString)”"
                    self.guessesLabel.text = ""
                    self.input.enabled = false
                default:
                    self.stateLabel.text = ""
                }
            })
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        let letterSet = NSCharacterSet.letterCharacterSet()
        if let inputText = textField.text where (inputText.characters.count == 1) && (inputText.rangeOfCharacterFromSet(letterSet) != nil) {
            // Send a message with details about the new guess to the server.
            let message = Phoenix.Message(message: ["letter": inputText])
            let payload = Phoenix.Payload(topic: "games:1", event: "new:guess", message: message)
            self.socket.send(payload)
            
            textField.text = ""
        }
        
        return false
    }

}

