$(document).ready(function () {
	// # Initialize select2 selects
	$('select.select2').select2({
		width: 'resolve', dropdownAutoWidth: true
	});

	// Close select2 on escape
	$('.js-select2').on('select2-close', function () {
		setTimeout(function () {
			$('.select2-container-active').removeClass('select2-container-active');
			$(':focus').blur();
		});
	});
});

