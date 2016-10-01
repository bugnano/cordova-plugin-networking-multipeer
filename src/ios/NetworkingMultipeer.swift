// Copyright 2016 Franco Bugnano
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import MultipeerConnectivity

@objc(NetworkingMultipeer) class NetworkingMultipeer: CDVPlugin, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
	var localPeerID: MCPeerID!

	var session: MCSession!

	var serviceAdvertiser: MCNearbyServiceAdvertiser?
	var serviceBrowser: MCNearbyServiceBrowser?

	var nextPeerID: Int!
	var knownPeers: [Int: MCPeerID]!

	var nextInvitationId: Int!
	var invitationHandlers: [Int: (Bool, MCSession) -> Void]!

	var idForAdvertisingError: String?
	var idForBrowsingError: String?
	var idForFoundPeer: String?
	var idForLostPeer: String?
	var idForReceiveInvitation: String?
	var idForReceiveData: String?
	var idForChangeState: String?

	override func pluginInitialize() {
		// It seems that Cordova does not call the default initializer, so
		// the member variables are not automatically initalized.
		// In order to be sure that the variables have a sane initial value,
		// they must be initialized here
		self.nextPeerID = 1
		self.knownPeers = [:]

		self.nextInvitationId = 0
		self.invitationHandlers = [:]

		// Init self.localPeerID
		let myName = UIDevice.current.name
		let defaults = UserDefaults.standard

		// Use the stored peer id, as long as its display name matches the current one
		if let peerIDData = defaults.data(forKey: "kPeerIDKey"), let peerID = NSKeyedUnarchiver.unarchiveObject(with: peerIDData) as? MCPeerID, peerID.displayName == myName {
			self.localPeerID = peerID
		} else {
			let peerID = MCPeerID(displayName: myName)
			let peerIDData = NSKeyedArchiver.archivedData(withRootObject: peerID)

			defaults.set(peerIDData, forKey: "kPeerIDKey")
			defaults.synchronize()

			self.localPeerID = peerID
		}

		// Init self.session
		self.session = MCSession(peer: self.localPeerID, securityIdentity: nil, encryptionPreference: .optional)
		session.delegate = self

		// Init all the optionals to nil, just to be sure
		self.serviceAdvertiser = nil
		self.serviceBrowser = nil
		self.idForAdvertisingError = nil
		self.idForBrowsingError = nil
		self.idForFoundPeer = nil
		self.idForLostPeer = nil
		self.idForReceiveInvitation = nil
		self.idForReceiveData = nil
		self.idForChangeState = nil

		// Call the super init after all the members have a sane value
		super.pluginInitialize()
	}

	deinit {
		self.serviceAdvertiser?.stopAdvertisingPeer()
		self.serviceAdvertiser = nil

		self.serviceBrowser?.stopBrowsingForPeers()
		self.serviceBrowser = nil

		self.session.disconnect()
	}

	func registerAdvertisingError(_ command: CDVInvokedUrlCommand) {
		self.idForAdvertisingError = command.callbackId
	}

	func registerBrowsingError(_ command: CDVInvokedUrlCommand) {
		self.idForBrowsingError = command.callbackId
	}

	func registerFoundPeer(_ command: CDVInvokedUrlCommand) {
		self.idForFoundPeer = command.callbackId
	}

	func registerLostPeer(_ command: CDVInvokedUrlCommand) {
		self.idForLostPeer = command.callbackId
	}

	func registerReceiveInvitation(_ command: CDVInvokedUrlCommand) {
		self.idForReceiveInvitation = command.callbackId
	}

	func registerReceiveData(_ command: CDVInvokedUrlCommand) {
		self.idForReceiveData = command.callbackId
	}

	func registerChangeState(_ command: CDVInvokedUrlCommand) {
		self.idForChangeState = command.callbackId
	}

	func getLocalPeerInfo(_ command: CDVInvokedUrlCommand) {
		// Truncate the hash value to 32 bits, in order to have a comparable hash value
		// on both 32-bit and 64-bit platforms
		let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: [
			"id": 0,
			"name": self.localPeerID.displayName,
			"hash": NSNumber(value: UInt32(truncatingBitPattern: self.localPeerID.hash)),
		])

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func startAdvertising(_ command: CDVInvokedUrlCommand) {
		let pluginResult: CDVPluginResult

		if let serviceType = command.arguments[0] as? String, !serviceType.isEmpty {
			self.serviceAdvertiser?.stopAdvertisingPeer()
			// For some strange reason, MCNearbyServiceAdvertiser is not implemented as a failable initializer,
			// so we cannot use the code
			//if let advertiser = MCNearbyServiceAdvertiser(peer: self.localPeerID, discoveryInfo: nil, serviceType: serviceType) {
			// If the MCNearbyServiceAdvertiser initialization fails, an exception is thrown from
			// the Objective-C implementation, but unfortunately the Swift interface does not state that
			// it throws an exception, so we cannot use the code
			//if let advertiser = try? MCNearbyServiceAdvertiser(peer: self.localPeerID, discoveryInfo: nil, serviceType: serviceType) {
			// In order to work-around this huge problem, we use the workaround found at:
			// http://stackoverflow.com/questions/24710424/catch-an-exception-for-invalid-user-input-in-swift
			do {
				try TryCatch.try({
					let advertiser = MCNearbyServiceAdvertiser(peer: self.localPeerID, discoveryInfo: nil, serviceType: serviceType)
					self.serviceAdvertiser = advertiser
					advertiser.delegate = self
					advertiser.startAdvertisingPeer()
				})

				pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
			} catch {
				self.serviceAdvertiser = nil
				pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR)
			}
		} else {
			pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR)
		}

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func stopAdvertising(_ command: CDVInvokedUrlCommand) {
		self.serviceAdvertiser?.stopAdvertisingPeer()
		self.serviceAdvertiser = nil

		let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func startBrowsing(_ command: CDVInvokedUrlCommand) {
		let pluginResult: CDVPluginResult

		if let serviceType = command.arguments[0] as? String, !serviceType.isEmpty {
			self.serviceBrowser?.stopBrowsingForPeers()
			// The MCNearbyServiceBrowser has the same initialization problems as MCNearbyServiceAdvertiser
			do {
				try TryCatch.try({
					let browser = MCNearbyServiceBrowser(peer: self.localPeerID, serviceType: serviceType)
					self.serviceBrowser = browser
					browser.delegate = self
					browser.startBrowsingForPeers()
				})

				pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
			} catch {
				self.serviceBrowser = nil
				pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR)
			}
		} else {
			pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR)
		}

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func stopBrowsing(_ command: CDVInvokedUrlCommand) {
		self.serviceBrowser?.stopBrowsingForPeers()
		self.serviceBrowser = nil

		let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func invitePeer(_ command: CDVInvokedUrlCommand) {
		let pluginResult: CDVPluginResult

		if let browser = self.serviceBrowser, let id = command.arguments[0] as? Int, self.knownPeers[id] != nil {
			browser.invitePeer(self.knownPeers[id]!, to: self.session, withContext: nil, timeout: 0)

			pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
		} else {
			pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR)
		}

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func acceptInvitation(_ command: CDVInvokedUrlCommand) {
		self.handleInvitation(command, accept: true)
	}

	func declineInvitation(_ command: CDVInvokedUrlCommand) {
		self.handleInvitation(command, accept: false)
	}

	func disconnect(_ command: CDVInvokedUrlCommand) {
		self.session.disconnect()

		let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func getConnectedPeers(_ command: CDVInvokedUrlCommand) {
		var peers = [[String: AnyObject]]()

		for peerID in self.session.connectedPeers {
			peers.append([
				"id": NSNumber(value: self.getIdForPeer(peerID)),
				"name": NSString(string: peerID.displayName),
				"hash": NSNumber(value: UInt32(truncatingBitPattern: peerID.hash)),
			])
		}

		let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: peers)

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func sendDataReliable(_ command: CDVInvokedUrlCommand) {
		self.sendData(command, withMode: .reliable)
	}

	func sendDataUnreliable(_ command: CDVInvokedUrlCommand) {
		self.sendData(command, withMode: .unreliable)
	}

	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
		if let callbackId = self.idForAdvertisingError {
			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: error.localizedDescription)
			pluginResult?.setKeepCallbackAs(true)
			self.commandDelegate.send(pluginResult, callbackId: callbackId)
		}
	}

	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		let id = self.getIdForPeer(peerID)

		guard id != 0 else {
			print("BUG: Cannot receive invitation from local peer")
			// Politely decline the invitation before returning
			invitationHandler(false, self.session)
			return
		}

		if let callbackId = self.idForReceiveInvitation {
			// Store the invitation handler, in ordet to call it once the user has
			// decided whether to accept or decline the invitation
			let invitationId = self.nextInvitationId!
			self.nextInvitationId! += 1
			self.invitationHandlers[invitationId] = invitationHandler

			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsMultipart: [[
				"id": id,
				"name": peerID.displayName,
				"hash": NSNumber(value: UInt32(truncatingBitPattern: peerID.hash)),
			], invitationId])
			pluginResult?.setKeepCallbackAs(true)
			self.commandDelegate.send(pluginResult, callbackId: callbackId)
		} else {
			// Automatically decline the invitation
			invitationHandler(false, self.session)
		}
	}

	func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
		if let callbackId = self.idForBrowsingError {
			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: error.localizedDescription)
			pluginResult?.setKeepCallbackAs(true)
			self.commandDelegate.send(pluginResult, callbackId: callbackId)
		}
	}

	func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
		let id = self.getIdForPeer(peerID)

		guard id != 0 else {
			print("BUG: I just found the local peer")
			return
		}

		if let callbackId = self.idForFoundPeer {
			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: [
				"id": id,
				"name": peerID.displayName,
				"hash": NSNumber(value: UInt32(truncatingBitPattern: peerID.hash)),
			])
			pluginResult?.setKeepCallbackAs(true)
			self.commandDelegate.send(pluginResult, callbackId: callbackId)
		}
	}

	func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
		let id = self.getIdForPeer(peerID)

		guard id != 0 else {
			print("BUG: I just lost the local peer")
			return
		}

		if let callbackId = self.idForLostPeer {
			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: [
				"id": id,
				"name": peerID.displayName,
				"hash": NSNumber(value: UInt32(truncatingBitPattern: peerID.hash)),
			])
			pluginResult?.setKeepCallbackAs(true)
			self.commandDelegate.send(pluginResult, callbackId: callbackId)
		}
	}

	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		let id = self.getIdForPeer(peerID)

		guard id != 0 else {
			print("BUG: Cannot receive data from the local peer")
			return
		}

		if let callbackId = self.idForReceiveData {
			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsMultipart: [[
				"id": id,
				"name": peerID.displayName,
				"hash": NSNumber(value: UInt32(truncatingBitPattern: peerID.hash)),
			], data])
			pluginResult?.setKeepCallbackAs(true)
			self.commandDelegate.send(pluginResult, callbackId: callbackId)
		}
	}

	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
	}

	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
	}

	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
	}

	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		let id = self.getIdForPeer(peerID)
		let strState: String

		switch state {
			case .notConnected:
				strState = "NotConnected"

			case .connecting:
				strState = "Connecting"

			case .connected:
				strState = "Connected"
		}

		if let callbackId = self.idForChangeState {
			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsMultipart: [[
				"id": id,
				"name": peerID.displayName,
				"hash": NSNumber(value: UInt32(truncatingBitPattern: peerID.hash)),
			], strState])
			pluginResult?.setKeepCallbackAs(true)
			self.commandDelegate.send(pluginResult, callbackId: callbackId)
		}
	}

	func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
		// Automatically accept all certificates
		certificateHandler(true)
	}

	func getIdForPeer(_ peerID: MCPeerID) -> Int {
		let id: Int

		// the local peer id maps to 0
		if peerID == self.localPeerID {
			return 0
		}

		if let (k, _) = self.knownPeers.first(where: { $1 == peerID }) {
			// The peer is already known
			id = k
		} else {
			// The peer is not known yet, add it to self.knownPeers
			id = self.nextPeerID
			self.nextPeerID! += 1

			// TO DO -- Losing an unknown peer may be a bug...
			self.knownPeers[id] = peerID
		}

		return id
	}

	func handleInvitation(_ command: CDVInvokedUrlCommand, accept: Bool) {
		let pluginResult: CDVPluginResult

		if let invitationId = command.arguments[0] as? Int, self.invitationHandlers[invitationId] != nil {
			self.invitationHandlers[invitationId]!(accept, self.session)
			self.invitationHandlers[invitationId] = nil

			pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
		} else {
			pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR)
		}

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}

	func sendData(_ command: CDVInvokedUrlCommand, withMode mode: MCSessionSendDataMode) {
		let pluginResult: CDVPluginResult
		var peerIDs = [MCPeerID]()

		if let peers = command.arguments[0] as? [AnyObject], let data = command.arguments[1] as? Data {
			// Convert the numeric peer ids to MCPeerID
			for peer in peers {
				if let id = peer as? Int, let knownPeer = self.knownPeers[id] {
					peerIDs.append(knownPeer)
				}
			}

			// If the arrays are of the same size, it means that all the peer ids are correct
			if peerIDs.count == peers.count {
				do {
					try self.session.send(data, toPeers: peerIDs, with: mode)

					pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: data.count)
				} catch let error as NSError {
					pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error.localizedDescription)
				}
			} else {
				pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Invalid peer ids")
			}
		} else {
			pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Invalid arguments")
		}

		self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
	}
}

