//
//  ViewController.swift
//  TetheringApp
//
//  Created by npatil5  on 5/19/21.
//

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController {
    
    //IBOutlets
    @IBOutlet weak var JsonTextView: UITextView!
    @IBOutlet weak var userNameText: UITextField!
    @IBOutlet weak var passwordText: UITextField!
    @IBOutlet weak var statusText: UITextField!
    @IBOutlet weak var statusMessageText: UITextField!
    @IBOutlet weak var urlText: UITextField!
    @IBOutlet weak var requestLabel: UILabel!
    
    //MCPeerID uniquely identifies a user within a session
    var peerID: MCPeerID!
    //MCSession is the manager class that handles all multipeer connectivity
    var mcSession: MCSession!
    //MCAdvertiserAssistant is used for creating a session, telling others that we exist and handling invitations
    var mcAdvertiserAssistant: MCAdvertiserAssistant!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.passwordText.isSecureTextEntry = true
        self.userNameText.text = "UserName"
        self.passwordText.text = "1234"
        self.statusText.text = "00"
        self.statusMessageText.text = "Success"
        self.urlText.text = "https://httpbin.org/anything/oidc/loginservice"
        
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil,    encryptionPreference: .required)
        mcSession.delegate = self
    }
    
    //for Tethering
    @IBAction func buttonPressed(_ sender: UIButton) {
        let ac = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .alert)
        
        ac.addAction(UIAlertAction(title: "Host a session", style: .default)
            { (UIAlertAction) in
            self.mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "todo",
                                                          discoveryInfo: nil,
                                                        session: self.mcSession)
            self.mcAdvertiserAssistant.start()
          })
          
        ac.addAction(UIAlertAction(title: "Join a session", style: .default)
        { (UIAlertAction) in
                let mcBrowser = MCBrowserViewController(serviceType: "todo",
                                                   session: self.mcSession)
                mcBrowser.delegate = self
                self.present(mcBrowser, animated: true, completion: nil)
        })
            
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    //sendind url to the connectedPeer based on the POST or GET Method
    @IBAction func submitButton(_ sender: Any) {
        
        if mcSession.connectedPeers.count > 0 {
           
            guard let url = self.urlText.text, let username = self.userNameText.text, let password = self.passwordText.text, let status = self.statusText.text, let statusMessage = self.statusMessageText.text, let request = self.requestLabel.text else {
                return
            }
            let postRequestData: [String: String] = ["url": url, "username": username, "password": password, "status": status, "statusMessage": statusMessage, "request": request]
            
            if let dataURL: Data = try? JSONEncoder().encode(postRequestData) {
                do {
                    try self.mcSession.send(dataURL, toPeers: self.mcSession.connectedPeers, with: .reliable)
                    
                } catch let error as NSError {
                    print("\(error.localizedDescription)")
                }
            }
        }
    }
    
    //To toggle GET or POST
    @IBAction func switchbuttonClicked(_ sender: Any) {
        if (sender as AnyObject).isOn {
            requestLabel.text = "POST"
            self.userNameText.isHidden =  false
            self.passwordText.isHidden =  false
            self.statusText.isHidden =  false
            self.statusMessageText.isHidden =  false
        } else {
            requestLabel.text = "GET"
            self.userNameText.isHidden =  true
            self.passwordText.isHidden =  true
            self.statusText.isHidden =  true
            self.statusMessageText.isHidden =  true
        }
    }
    
    //POST Method
    private func postMethod(url: String, httpData: UploadData, completionHandler: @escaping (Data?, Error?) -> Void) {
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        guard let url = URL(string: url) else {
            print("Error: cannot create URL")
            return
        }
        
        // Add data to the model
        let uploadDataModel = UploadData(username: httpData.username, password: httpData.password, status: httpData.status, statusMessage: httpData.statusMessage)
        
        // Convert model to JSON data
        guard let jsonData = try? JSONEncoder().encode(uploadDataModel) else {
            print("Error: Trying to convert model to JSON data")
            return
        }
        // Create the url request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // the request is JSON
        request.setValue("application/json", forHTTPHeaderField: "Accept") // the response expected to be in JSON format
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, _, error  in
            if let error = error {
                completionHandler(nil, error)
            }
            
            if let data = data {
                completionHandler(data, nil)
            }
            
            dispatchGroup.leave()
        }.resume()
    }
    
    //GET Method
    private func getMethod(url: String, completionHandler: @escaping (Data?, Error?) -> Void) {
            guard let url = URL(string: url) else {
                print("Error: cannot create URL")
                return
            }
            // Create the url request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            URLSession.shared.dataTask(with: request) { data, _, error in
                guard error == nil else {
                    completionHandler(nil, error)
                    return
                }
                guard let data = data else {
                    completionHandler(nil, error)
                    return
                }
                completionHandler(data, nil)
            }.resume()
        }
}

//MCBrowserViewController is used when looking for sessions, showing users who is nearby and letting them join.
extension ViewController: MCSessionDelegate, MCBrowserViewControllerDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
            case .connected: print ("connected \(peerID)")
            case .connecting: print ("connecting \(peerID)")
            case .notConnected: print ("not connected \(peerID)")
            default: print("unknown status for \(peerID)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let jsonString = String(decoding: data, as: UTF8.self)
        DispatchQueue.main.async  {
            self.JsonTextView.text = jsonString
        }
        
        do {
         let decodedData = try JSONDecoder().decode([String: String].self, from: data)
            let httpData = UploadData(username: decodedData["username"] ?? " ",
                                      password: decodedData["password"] ?? " ",
                                      status: decodedData["status"] ?? " " ,
                                      statusMessage: decodedData["statusMessage"] ?? " ")
        
            guard let urlRequestMethod = decodedData["request"] else {
                return
            }
            
            if urlRequestMethod == "POST" {
                 postMethod(url: decodedData["url"] ?? " ", httpData: httpData, completionHandler: { data, error in
                       if let error = error {
                           print("error: \(error)")
                       }
                       
                        guard let safeData = data else {
                            return
                        }
                        
                        try? self.mcSession.send(safeData, toPeers: self.mcSession.connectedPeers, with: .reliable)
                 })
            } else {
                getMethod(url: decodedData["url"] ?? " ") { data, error in
                    if let error = error {
                        print("error: \(error)")
                    }
                    
                     guard let safeData = data else {
                         return
                     }
                     
                     try? self.mcSession.send(safeData, toPeers: self.mcSession.connectedPeers, with: .reliable)
                }
            }
        } catch {
            print("Invalid response from server: \(error)")
       }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }

    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
    }
}
