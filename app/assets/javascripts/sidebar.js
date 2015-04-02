$(document).tooltip({
	selector: '.page-sidebar-collapsed .nav-sidebar a',
	placement: 'right'
});

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

	$.cookie("collapsed_nav", $('.page-with-sidebar').hasClass(collapsed), { path: '/' });
});
