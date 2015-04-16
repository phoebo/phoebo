(function (BuildRequestsController) {

// BuildRequest#new
BuildRequestsController.prototype.new = function () {
  var xhr;
  var $projectSelect = $('SELECT[name="' + 'build_request[project_id]' + '"]');
  var $branchSelect  = $('SELECT[name="' + 'build_request[branch]' + '"]');

  function updateBranchSelect(value) {
    if(!value.length) return ;
    var branchSelect = $branchSelect[0].selectize;
    branchSelect.disable();
    branchSelect.clearOptions();
    branchSelect.load(function (callback) {
      xhr && xhr.abort();
      xhr = $.ajax({
        url: '/projects/' + encodeURIComponent(value) + '/commits',
        success: function (results) {
          branchSelect.enable();
          callback(results['commits']);

          if(results['commits'].length)
            branchSelect.setValue(results['commits'][0]['id']);
        },
        error: function() {
          callback();
        }
      });
    });
  }

  $projectSelect.selectize({
    onChange: updateBranchSelect
  });

  $branchSelect.selectize({
    valueField: 'id',
    labelField: 'branch'
  });

  updateBranchSelect($projectSelect.val());
};

})(Paloma.controller('BuildRequests'));