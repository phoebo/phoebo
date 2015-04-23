(function (SetupController) {

// Setup#index
SetupController.prototype.index = function () {
	var websocket = UpdateStream.open();
  var _this = this;

	websocket.onmessage = function (event) {
    if(event.data.length) {
      var data = JSON.parse(event.data);
      if(data.state) {

        // Redirect when setup is done
        if(data.state == _this.params['state_done']) {
          UpdateStream.close();
          Turbolinks.visit(_this.params['root_path'])
        }

        // Show error when setup failed
        else if(data.state == _this.params['state_failed']) {
          UpdateStream.close();

          if(data.state_message)
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
};

})(Paloma.controller('Setup'));