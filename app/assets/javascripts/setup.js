(function (SetupController) {

SetupController.prototype = {

  index: function () {
    var _this = this;

    this._websocketInit();
    this.websocket.onmessage = function (event) {
      if(event.data.length) {
        var data = JSON.parse(event.data);
        console.log(data);
      }
    };
  },

  // --------------

  _websocketInit: function () {
    if(this.websocket) {
      this.websocket.close();
    }

    var url = "ws://" + window.location.host + this.params['url'];
    this.websocket = new WebSocket(url);
  },

};

})(Paloma.controller('Setup'));