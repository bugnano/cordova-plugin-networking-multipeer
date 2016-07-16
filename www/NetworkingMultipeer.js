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

var
	exec = require('cordova/exec'),
	channel = require('cordova/channel'),
	CDVNetEvent = require('cordova-plugin-networking-multipeer.CDVNetEvent')
;

exports.getLocalPeerInfo = function(success, error) {
	exec(success, error, 'NetworkingMultipeer', 'getLocalPeerInfo', []);
};

exports.startAdvertising = function(serviceType, success, error) {
	exec(success, error, 'NetworkingMultipeer', 'startAdvertising', [serviceType]);
};

exports.stopAdvertising = function(success, error) {
	exec(success, error, 'NetworkingMultipeer', 'stopAdvertising', []);
};

exports.startBrowsing = function(serviceType, success, error) {
	exec(success, error, 'NetworkingMultipeer', 'startBrowsing', [serviceType]);
};

exports.stopBrowsing = function(success, error) {
	exec(success, error, 'NetworkingMultipeer', 'stopBrowsing', []);
};

exports.invitePeer = function (peerId, success, error) {
	exec(success, error, 'NetworkingMultipeer', 'invitePeer', [peerId]);
};

exports.acceptInvitation = function (invitationId, success, error) {
	exec(success, error, 'NetworkingMultipeer', 'acceptInvitation', [invitationId]);
};

exports.declineInvitation = function (invitationId, success, error) {
	exec(success, error, 'NetworkingMultipeer', 'declineInvitation', [invitationId]);
};

exports.disconnect = function (success, error) {
	exec(success, error, 'NetworkingMultipeer', 'disconnect', []);
};

exports.getConnectedPeers = function (success, error) {
	exec(success, error, 'NetworkingMultipeer', 'getConnectedPeers', []);
};

exports.sendDataReliable = function (peers, data, success, error) {
	if (typeof peers === 'number') {
		peers = [peers];
	}

	exec(success, error, 'NetworkingMultipeer', 'sendDataReliable', [peers, data]);
};

exports.sendDataUnreliable = function (peers, data, success, error) {
	if (typeof peers === 'number') {
		peers = [peers];
	}

	exec(success, error, 'NetworkingMultipeer', 'sendDataUnreliable', [peers, data]);
};

// Events
exports.onAdvertisingError = Object.create(CDVNetEvent);
exports.onAdvertisingError.init();

exports.onBrowsingError = Object.create(CDVNetEvent);
exports.onBrowsingError.init();

exports.onFoundPeer = Object.create(CDVNetEvent);
exports.onFoundPeer.init();

exports.onLostPeer = Object.create(CDVNetEvent);
exports.onLostPeer.init();

exports.onReceiveInvitation = Object.create(CDVNetEvent);
exports.onReceiveInvitation.init();

exports.onReceiveData = Object.create(CDVNetEvent);
exports.onReceiveData.init();

exports.onChangeState = Object.create(CDVNetEvent);
exports.onChangeState.init();

channel.onCordovaReady.subscribe(function() {
	exec(function (errorMessage) {
		exports.onAdvertisingError.fire(errorMessage);
	}, null, 'NetworkingMultipeer', 'registerAdvertisingError', []);

	exec(function (errorMessage) {
		exports.onBrowsingError.fire(errorMessage);
	}, null, 'NetworkingMultipeer', 'registerBrowsingError', []);

	exec(function (peerInfo) {
		exports.onFoundPeer.fire(peerInfo);
	}, null, 'NetworkingMultipeer', 'registerFoundPeer', []);

	exec(function (peerInfo) {
		exports.onLostPeer.fire(peerInfo);
	}, null, 'NetworkingMultipeer', 'registerLostPeer', []);

	exec(function (peerInfo, invitationId) {
		exports.onReceiveInvitation.fire({
			peerInfo: peerInfo,
			invitationId: invitationId
		});
	}, null, 'NetworkingMultipeer', 'registerReceiveInvitation', []);

	exec(function (peerInfo, data) {
		exports.onReceiveData.fire({
			peerInfo: peerInfo,
			data: data
		});
	}, null, 'NetworkingMultipeer', 'registerReceiveData', []);

	exec(function (peerInfo, state) {
		exports.onChangeState.fire({
			peerInfo: peerInfo,
			state: state
		});
	}, null, 'NetworkingMultipeer', 'registerChangeState', []);
});

