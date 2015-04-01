$(document).ready(function () {
	$(document).on("click", '.toggle-nav-collapse', function(e) {
		var collapsed, expanded;
		e.preventDefault();
		collapsed = 'page-sidebar-collapsed';
		expanded = 'page-sidebar-expanded';

		if ($('.page-with-sidebar').hasClass(collapsed)) {
			$('.page-with-sidebar').removeClass(collapsed).addClass(expanded);
			$('.toggle-nav-collapse i').removeClass('fa-angle-right').addClass('fa-angle-left');
		} else {
			$('.page-with-sidebar').removeClass(expanded).addClass(collapsed);
			$('.toggle-nav-collapse i').removeClass('fa-angle-left').addClass('fa-angle-right');
		}
	});

	$('.has_bottom_tooltip').each(function () {
		$(this).tooltip();
	});
});