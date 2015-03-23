# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$(document).on "page:change", ->
  if window.socket
    window.socket.close()

  window.socket = new WebSocket "ws://#{window.location.host}" + $('#output').data('url')
  window.socket.onmessage = (event) ->
    if event.data.length
      $("#output").append "#{event.data}<br>"
      $("#output").stop().animate({ scrollTop: $('#output')[0].scrollHeight}, 200)