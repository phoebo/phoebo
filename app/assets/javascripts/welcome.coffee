# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$ ->
  socket = new WebSocket "ws://#{window.location.host}/update_stream"
  socket.onmessage = (event) ->
    if event.data.length
      $("#output").append "#{event.data}<br>"
      $("#output").animate({ scrollTop: $('#output')[0].scrollHeight}, 200)