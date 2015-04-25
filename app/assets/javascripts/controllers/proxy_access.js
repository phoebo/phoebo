(function (ProxyAccessController) {

// ProxyAccess#show
ProxyAccessController.prototype.show = function () {
  $('.proxy-access INPUT[type=password]').focus();
};

})(Paloma.controller('ProxyAccess'));

