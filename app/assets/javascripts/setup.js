(function (SetupController) {

SetupController.prototype = {

  index: function () {
    var _this = this;

    this._websocketInit();

    $(document).on('page:before-unload', function () {
      if(_this.websocket) {
        _this.websocket.close();
      }
    });

    this.websocket.onmessage = function (event) {
      if(event.data.length) {
        var data = JSON.parse(event.data);
        if(data.state) {

          // Redirect when setup is done
          if(data.state == _this.params['state_done']) {
            _this.websocket.close();
            Turbolinks.visit(_this.params['root_path'])
          }

          // Show error when setup failed
          else if(data.state == _this.params['state_failed']) {
            _this.websocket.close();
            $('.setup-error').text(data.state_message);

            $('.setup-inprogress').fadeOut(function () {
              $('.setup-failed').fadeIn();
            });
          }

          // In progress
          else {
           $('.setup-inprogress').fadeIn();
          }
        }
      }
    };
  },

  // --------------

  _websocketInit: function () {
    if(this.websocket) {
      this.websocket.close();
    }

    var url = "ws://" + window.location.host + this.params['watch_path'];
    this.websocket = new WebSocket(url);
  },

};

})(Paloma.controller('Setup'));