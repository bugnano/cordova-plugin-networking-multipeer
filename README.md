<!--
# license: Copyright 2016 Franco Bugnano
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
-->

# cordova-plugin-networking-multipeer


This plugin provides Multipeer Connectivity for peer to peer networking between iOS devices,
using infrastructure Wi-Fi networks, peer-to-peer Wi-Fi, and Bluetooth personal area networks.

## Installation

    cordova plugin add cordova-plugin-networking-multipeer

## Supported Platforms

- iOS

# Namespace and API

All the functions and events described in this plugin reside in the `networking.multipeer` namespace.

All the functions are asynchronous and have 2 callbacks as their last 2 parameters, the first
being the success callback, and the second being the error callback.

All the events have the following methods:

```javascript
Event.addListener(function callback)
Event.removeListener(function callback)
boolean Event.hasListener(function callback)
boolean Event.hasListeners()
```

# Adapter information

To obtain information of the local peer, use the `getLocalPeerInfo` method: 

```javascript
var localPeer;
networking.multipeer.getLocalPeerInfo(function (peerInfo) {
    // The peerInfo object has the following properties:
    // id: Number --> A session-specific numerical ID that represents the peer
    // name: String --> The human-readable name of the peer
    // hash: Number --> A hash value that can be useful for deciding which peer should invite
    localPeer = peerInfo;
    console.log('id: ' + peerInfo.id);
    console.log('name: ' + peerInfo.name);
});
```

# Device discovery (browsing and advertising)

To begin discovery of nearby devices, use the `startBrowsing` method.
Discovery can be resource intensive so you should call `stopBrowsing` once the connection has been succesfully established.

You should call `startBrowsing` whenever your app needs to discover nearby devices.

Information about each newly discovered device is received using the `onFoundPeer` event.

If a previously discovered device is not reachable anymore, the `onLostPeer` event will be fired.

Example:

```javascript
var device_names = {};
var last_peer_id;
var updateDeviceName = function (peerInfo) {
    device_names[peerInfo.id] = peerInfo.name;
    last_peer_id = peerInfo.id;
};

// Add listener to receive newly found devices
networking.multipeer.onFoundPeer.addListener(updateDeviceName);

// Now begin the discovery process.
var serviceType = 'xx-service'; // serviceType is a 1-15 character long string that can contain only ASCII lowercase letters, numbers, and hyphens
networking.multipeer.startBrowsing(serviceType, function () {
    // The device is now discovering
}, function () {
    // There was an error
});

// If you want to stop discovering
networking.multipeer.stopBrowsing();
```

To make the device discoverable, use the `startAdvertising` function, that will make the device discoverable.

To stop making the device discoverable, for example once all the peers have been connected, use the `stopAdvertising` function.

```javascript
var serviceType = 'xx-service'; // serviceType is a 1-15 character long string that can contain only ASCII lowercase letters, numbers, and hyphens
networking.multipeer.startAdvertising(serviceType, function () {
    // The device is now discoverable
}, function () {
    // There was an error making the device discoverable
});

// If you want to stop advertising
networking.multipeer.stopAdvertising();
```

# Connecting peers

With Multipeer Connectivity, the devices that are discovering (browsing) send an invitation to the devices that are
discoverable (advertising), that in turn accept or decline the invitation.

In order to send an invitation, the device must be browsing, so be sure to send the invitation before calling the `stopBrowsing`
function.

Example:

```javascript
networking.multipeer.invitePeer(last_peer_id, function () {
    // The invitation has been sent, but the connection is not yet established.
    // The connection will be succesfully established once the onChangeState event
    // will be fired with the expected peer id and the 'Connected' state
}, function () {
    console.log('Invitation failed');
});
```

On the other end, in order to accept or decline the invitation, the device must be advertising,
so be sure to have handled the invitation before calling the `stopAdvertising` function.

Example:

```javascript
networking.multipeer.onReceiveInvitation.addListener(function (invitationInfo) {
    // invitationInfo.peerInfo --> The inviting peer
    // invitationInfo.invitationId --> The id to use for accepting or declining the invitation
    // To decline the invitation, simply call declineInvitation instead of acceptInvitation
    networking.multipeer.acceptInvitation(invitationInfo.invitationId, function () {
        // The invitation has been accepted, but the connection is not yet established.
        // The connection will be succesfully established once the onChangeState event
        // will be fired with the expected peer id and the 'Connected' state
    }, function () {
        // There was an error accepting the invitation
    });
});
```

OPTIONAL: In order to implement automatic connection, the devices can be both browsing and advertising at the same time,
so, in order to have only one device sending the invitaton, the `hash` attribute can be compared like this:

```javascript
networking.multipeer.onFoundPeer.addListener(function (peerInfo) {
    // When all the devices are both browsing and advertising,
    // this guarantees that only one device sends the invitation
    if (localPeer.hash > peerInfo.hash) {
        networking.multipeer.invitePeer(peerInfo.id);
    }
});
```

A list of the currently connected peers can always be obtained by calling the `getConnectedPeers` function.

```javascript
networking.multipeer.getConnectedPeers(function (peers) {
    // peers is an array of peerInfo objects
    for (var i = 0; i < peers.length; i++) {
        console.log(peers[i].name);
    }
});
```

# Receiving and sending data

Receiving and sending data uses [ArrayBuffer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Typed_arrays) objects.

Sending data can be done either in reliable mode, or in unreliable mode.

To send data you have in `arrayBuffer` use `sendDataReliable` or `sendDataUnreliable`:

```javascript
// The first argument to sendDataReliable and sendDataUnreliable can be either a single
// peer id, or an array containing all the peer ids that should receive the data
networking.multipeer.sendDataReliable(last_peer_id, arrayBuffer, function (bytes_sent) {
    console.log('Sent ' + bytes_sent + ' bytes');
}, function (errorMessage) {
    console.log('Send failed: ' + errorMessage);
})
```

In contrast to the methods to send data, data is received in a single event (`onReceiveData`).

```javascript
networking.multipeer.onReceiveData.addListener(function (receiveInfo) {
    // receiveInfo is an object with the following members:
    // peerInfo --> The peer who sent the data
    // data --> ArrayBuffer
    if (receiveInfo.peerInfo.id !== last_peer_id) {
        return;
    }

    // receiveInfo.data is an ArrayBuffer.
});
```

# Receiving connection/disconnection

To be notified of peer connection/disconnection, add a listener to the `onChangeState` event.

```javascript
networking.multipeer.onChangeState.addListener(function (stateInfo) {
    // stateInfo is an object with the following members:
    // peerInfo --> The peer whose state is changed (a complete peerInfo object, not just its id)
    // state --> A string that can contain one of the following values:
    //  'NotConnected'
    //  'Connecting'
    //  'Connected'
    if (stateInfo.peerInfo.id !== last_peer_id) {
        return;
    }

    console.log(stateInfo.state);
});
```

# Disconnecting

To hang up the connection and disconnect use `disconnect`.

```javascript
networking.multipeer.disconnect();
```

<!-- vim: set et: -->

