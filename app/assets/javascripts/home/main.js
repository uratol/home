function message(msg){
	$('#flash_messages').text(msg);
}

var onAjaxError = function (request, ajaxOptions, thrownError) {
			if (thrownError)
	        	message(thrownError+': '+request.responseText.substring(0,550));
	     };

function setBrightness(elem, brightness) {
	f = 'brightness(' + brightness + '%)';
	elem.css('-webkit-filter', f);
	elem.css('filter', f);
};

var refreshInterval = 0;
function setRefreshInterval(interval){
	if (refreshInterval != 0){ clearInterval(refreshInterval) };

	refreshInterval = setInterval(function() {
		refreshRequest();
	}, interval);
}

function refreshEntityes(entities) {
	entities.forEach(function(entity) {
		commonRefresh(entity);
	});
};

function commonRefresh(entity){
	container = $('.entity').filter('#' + entity.id);

	elem = container.find('#img' + entity.id);
	if (elem.attr('src') != entity.img) {
		elem.attr('src', entity.img);
	};
	capt = container.find('#caption' + entity.id);
	if (capt != null && entity.text != undefined)
		capt.text(entity.text);
	if (entity.brightness != undefined)
		setBrightness(elem, entity.brightness);
	container.trigger('entity:refresh', entity);	
}

function refreshRequest() {
	if (!$('.layout_container').length)
		return;
		
	$.ajax({
		 url: "/main/refresh?root=" + $(".layout_container").attr('id')
		,success: function(data) {
			refreshEntityes(data);
			}
		,error: onAjaxError
	});

};

function arrangeLayout() {
	//lc.height(lc[0].scrollHeight);

	var maxRight = 0, maxBottom = 0, tmpInt;
	
	function calcChildrenBounds(e){
		e.children(':not(script)').each(function(){
			tmpInt = $(this).offset().top + $(this).outerHeight(true);
			if (tmpInt > maxBottom) { 
				maxBottom = tmpInt;
			};
	
			tmpInt = $(this).offset().left + $(this).outerWidth(true);
			if (tmpInt > maxRight) { 
				maxRight = tmpInt;
			};
			
			if (!$(this).hasClass('chart_div') ) {
				calcChildrenBounds($(this));
			};
		});
		
	};
	
	$(".layout_container").each(function(){
		calcChildrenBounds($(this));
	});

	$('.layout_container').width(maxRight - $('.layout_container').offset().left);
	$('.layout_container').height(maxBottom - $('.layout_container').offset().top);
};

function act(elem, action){
		if(isDesignMode) return;
		
		var ent_id;
		ent_id = $(elem).data('twin');
		if (!ent_id)
			ent_id = elem.id;  
		
		$.ajax({
			 url: '/main/' + action
			,method: 'POST'
			,data: {root: $('.layout_container').attr('id'), id: ent_id}
			,success: function(data) {
				refreshEntityes(data);
				}
			,error: onAjaxError
		});
	}
	
var ready = function(){
	$(".at_click, .at_touchstart, .at_touchend").hover(function(){
		if ($(this).data('twin'))
			$els = $("div[data-twin="+$(this).data('twin')+"]");
		else	
			$els = $(this);
		  
		$els.toggleClass('hover');
	});
	
	$(".at_touchstart").bind("touchstart mousedown", function(e){ e.preventDefault(); act(this, 'touchstart'); });
	$(".at_click, .at_dbl_click").click(function(){ act(this, 'click'); });
	$(".at_touchend").bind("touchend mouseup", function(e){ e.preventDefault(); act(this, 'touchend'); });
	

	refreshRequest();

	if ($('.layout_container').length) {
		// setup height container by content
		// browser needs timeout for building elements
		setTimeout(function() {
		arrangeLayout();
		}, 500);
	};
	setRefreshInterval(5000);
};

//$(document).on('page:change', ready);
$(document).on('turbolinks:load', ready);

/*
$(document).on('page:change', function() {
	
	$(".at_click").hover(function(){
		
		if ($(this).data('twin'))
			$els = $(".at_click[data-twin="+$(this).data('twin')+"]");
		else	
			$els = $(this);
		  
		$els.toggleClass('hover');
	});
	
	$(".at_click").click(function(){
		if(isDesignMode) return;
		
		var ent_id;
		ent_id = $(this).data('twin');
		if (!ent_id)
			ent_id = this.id;  
		
		$.ajax({
			 url: '/main/click'
			,data: {root: $(".layout_container").attr('id'), id: ent_id}
			,success: function(data) {
				refreshEntityes(data);
				}
			,error: onAjaxError
		});
	});
	

	refreshRequest();

	if ($('.layout_container').length) {
		// setup height container by content
		// browser needs timeout for building elements
		setTimeout(function() {
		arrangeLayout();
		}, 500);
	};
});
*/