(function (ProjectsController) {

// Projects#index
ProjectsController.prototype.index = function () {
  $('.projects').on('click', '.btn-enable', function () {
    var href = $(this).attr('href');

    bootbox.dialog({
      message: "Are you sure you want to enable CI for this project?<ul style='margin-top: 1em'><li>All project users will be allowed to run tasks on CI.</ul>",
      title: "Enable CI",
      buttons: {
        cancel: {
          label: "Cancel",
          className: "btn-default"
        },
        danger: {
          label: "Enable CI",
          className: "btn-new",
          callback: function() {
            window.location = href;
          }
        }
      }
    });

    return false;
  });

  $('.projects').on('click', '.btn-disable', function () {
    var href = $(this).attr('href');

    bootbox.dialog({
      message: "Are you sure you want to disable CI for this project?<ul style='margin-top: 1em'><li>All settings will be removed.<li>If any task is running it will be left untouched.</ul>",
      title: "Disable CI",
      buttons: {
        cancel: {
          label: "Cancel",
          className: "btn-default"
        },
        danger: {
          label: "Disable CI",
          className: "btn-danger",
          callback: function() {
            window.location = href;
          }
        }
      }
    });

    return false;
  });
};

})(Paloma.controller('Projects'));

