(function (ProjectSettingsController) {

// ProjectSettings#show
ProjectSettingsController.prototype.show = function () {
  var $containers = $('.params-container');

  // Param change
  $containers.on('change', 'INPUT', function () {
    var $input     = $(this);
    var $param     = $input.closest('.param');
    var $container = $param.closest('.params-container');

    // Is this param empty?
    var empty = true;
    $param.find('INPUT').each(function () {
      if($(this).val() != '' && $(this).attr('type') != 'hidden')
        empty = false;
    });

    // Update class
    if(empty) $param.addClass('param-empty');
    else $param.removeClass('param-empty');

    // Add new param if necessary
    if(!empty && $container.find('.param-empty').length == 0) {

      // Clone param
      var $newParam = $param.clone(true);

      // Set as empty
      $newParam.addClass('param-empty');

      // Clear inputs
      $newParam.find('INPUT').each(function () {
        $(this).val('');

        // Update name
        $(this).attr('name', $(this).attr('name').replace(/\[([0-9]+)(\]\[[^\]]+\])$/, function (match, p1, p2, offset, string) {
          return '[' + (parseInt(p1) + 1) + p2;
        }));
      });

      // Append param
      $newParam.hide();
      $container.append($newParam);
      $newParam.slideDown();
    }

    // Remove param if necessary
    else if(empty && $container.children().length > 0) {

      // Set destroy flag
      $param.find('INPUT[type=hidden][name$="[_destroy]"]').val(true);

      // Hide it
      $param.slideUp();
    }
  });

  // Type select
  $containers.on('click', 'UL.dropdown-menu LI A', function () {
    var $item     = $(this);
    var $btnGroup = $item.closest('.input-group-btn');
    var $input    = $btnGroup.closest('.input-group').find('INPUT');

    // Update text in dropdown-toogle
    $btnGroup.find('BUTTON .current').html($item.html());

    // Clear text if it was password
    if($input.attr('type') == 'password')
      $input.val('');

    // Set corresponding input type
    $input.attr('type', $item.data('type'));

    // Update hidden field
    $btnGroup.closest('.param').find('INPUT[type=hidden][name$="[secret]"]').val($input.attr('type') == 'password');

    // Focus
    $input.focus();
  });

};

})(Paloma.controller('ProjectSettings'));

