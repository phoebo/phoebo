// Update stream definition
(function () {
	window.UpdateStream = window.UpdateStream || {};

	// Opening the stream
	UpdateStream.open = function (path) {
		if(!path) {
			var req = Paloma.engine.getRequest();
			if(req.params['update_stream_url'])
				path = req.params['update_stream_url'];
			else
				console.error("No update stream URL");
		}

		// console.log('Opening an update stream');

		var url = "ws://" + window.location.host + path;
		window.UpdateStream.socket = new WebSocket(url);
		return window.UpdateStream.socket;
	};

	// Closing the stream
	UpdateStream.close = function () {
		if(UpdateStream.socket) {
			// console.log('Closing update stream');

			UpdateStream.socket.close();
			delete window.UpdateStream.socket;
		}
	};

})();

// We ensure UpdateStream gets closed if user leaves the page using Turbolinks
(function () {
	$(document).on('page:before-unload', function() {
		if(window.UpdateStream.socket)
			window.UpdateStream.close();
	});
})();

// We ensure Paloma triggers event for stream-enabled actions
// when user goes Back in page view history
(function () {
	var FakeEngine = function () { };
	FakeEngine.prototype.setRequest = function (resource, action, params) {
		Paloma.engine = Paloma.realEngine;

		if(params['update_stream_url']) {
			if(Paloma.env == 'development')
				console.log('Restoring update stream: ' + params['update_stream_url']);

			Paloma.engine.setRequest(resource, action, params);
			Paloma.engine.start();
		}
	};

	$(document).on('page:restore', function (event) {
		if(!Paloma.fakeEngine) {
			Paloma.fakeEngine = new FakeEngine;
			Paloma.realEngine = Paloma.engine;
		}

		Paloma.engine = Paloma.fakeEngine;
		Paloma.executeHook();
	});
})();
