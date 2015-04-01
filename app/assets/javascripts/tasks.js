(function (TasksController) {

TasksController.prototype = {

  index: function () {
    var _this = this;
    var $container = $('.task-listing');

    this._websocketInit();
    this.websocket.onmessage = function (event) {
      var data = JSON.parse(event.data);

      if(data && data != 'subscribed') {
        for(var taskId in data) break;

        var $task = $container.find("[data-task-id=\"" + taskId + "\"]")
        if($task.length == 0) {
          $task = $('<div class="task" />').attr('data-task-id', taskId);
          $task.append($('<a class="name" />').attr('href', _this._taskUrl(taskId)).text(taskId));
          $task.append($('<span class="state" />'));

          var $build = data[taskId]['build']
            ? $container.find('[data-build-id="' + data[taskId]['build']['id'] + '"]')
            : $container.find('[data-build-id="0"]');

          if($build.length == 0) {
            $build = $('<div class="build" />').attr('data-build-id', data[taskId]['build'] ? data[taskId]['build']['id'] : 0);

            var $buildInfo = $('<div class="info" />');

            if(data[taskId]['build']) {
              $buildInfo.append($('<span class="ns" />').text(data[taskId]['build']['name'][0]));
              $buildInfo.append($('<span class="ns-separator">/</span>'));
              $buildInfo.append($('<span class="name" />').text(data[taskId]['build']['name'][1]));
              $buildInfo.append($('<span class="ref-separator">@</span>'));
              $buildInfo.append($('<span class="ref" />').text(data[taskId]['build']['ref']));
            } else {
              $buildInfo.append($('<span class="name" />').text('Non-project tasks'));
            }

            $build.append($buildInfo)
            $build.append($('<div class="tasks" />'));

            $container.prepend($build);
          }

          $build.find('.tasks').append($task);
        }

        $task.find('.state').text(data[taskId]['state']);
      }
    };
  },

  show: function () {
    var $wrapper = $('.task-detail'),
        $state   = $wrapper.find('.state'),
        $log     = $wrapper.find('.log');

    this._websocketInit();
    this.websocket.onmessage = function (event) {
      if(event.data.length) {
        var data = JSON.parse(event.data);
        for(var taskId in data) break;

        if(data[taskId]['log']) {
          var log = data[taskId]['log'];
          log = log.replace(/[\u00A0-\u9999<>\&]/gim, function(i) {
              return '&#' + i.charCodeAt(0) + ';';
          });

          log = log.replace(/\[0;([0-9]+);49m(.+?)\[0m/g, '<span class="console-color-$1">$2</span>');

          $log.append($('<div>').html(log));
          $log.stop().animate({ scrollTop: $log[0].scrollHeight}, 200);

        } else if(data[taskId]['state']) {
          $state.text(data[taskId]['state']);
        }
      }
    };
  },

  // --------------

  _websocketInit: function () {
    if(this.websocket) {
      this.websocket.close();
    }

    var _this = this;
    $(document).on('page:before-unload', function () {
      if(_this.websocket) {
        _this.websocket.close();
      }
    });

    var url = "ws://" + window.location.host + this.params['url'];
    this.websocket = new WebSocket(url);
  },

  _taskUrl: function (taskId) {
    return "/tasks/" + encodeURIComponent(taskId)
  }

};

})(Paloma.controller('Tasks'));