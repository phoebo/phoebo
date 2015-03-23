(function (TasksController) {

TasksController.prototype = {

  index: function () {
    var _this = this;
    var $tasks = $('.task-listing');

    this._websocketInit();
    this.websocket.onmessage = function (event) {
      if(event.data.length) {
        var data = JSON.parse(event.data);
        for(var taskId in data) break;

        var $task = $tasks.find("[data-task-id=\"" + taskId + "\"]")
        if($task.length == 0) {
          $task = $('<div class="task" />').attr('data-task-id', taskId);
          $tasks.prepend($task);
          $task.append($('<a class="name" />').attr('href', _this._taskUrl(taskId)).text(taskId));
          $task.append($('<span class="state" />'));
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
          $log.append($('<div>').text(data[taskId]['log']));
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

    var url = "ws://" + window.location.host + this.params['url'];
    this.websocket = new WebSocket(url);
  },

  _taskUrl: function (taskId) {
    return "/tasks/" + encodeURIComponent(taskId)
  }

};

})(Paloma.controller('Tasks'));