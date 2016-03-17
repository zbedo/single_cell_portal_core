// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require bootstrap-sprockets
//= require jquery-ui/core
//= require jquery-ui/datepicker
//= require spin.min
//= require_tree .

// toggle chevron glyphs on clicks
function toggleGlyph(el) {
    el.toggleClass('fa-chevron-right fa-chevron-down');
}

// attach various handlers to bootstrap items
$(function() {
    $('.panel-heading').click(function () {
        var anchor = $(this).find('a')
        $(anchor)[0].click();
    });

    $('.panel-collapse').on('show.bs.collapse', function (e) {
        toggleGlyph($(this).prev().find('span.fa'));
    });

    $('.panel-collapse').on('hide.bs.collapse', function (e) {
        toggleGlyph($(this).prev().find('span.fa'));
    });

    $('[data-toggle="tooltip"]').tooltip();
});

// options for Spin.js
var opts = {
    lines: 13 // The number of lines to draw
    , length: 50 // The length of each line
    , width: 14 // The line thickness
    , radius: 42 // The radius of the inner circle
    , scale: 0.4 // Scales overall size of the spinner
    , corners: 1 // Corner roundness (0..1)
    , color: '#000' // #rgb or #rrggbb or array of colors
    , opacity: 0.25 // Opacity of the lines
    , rotate: 21 // The rotation offset
    , direction: 1 // 1: clockwise, -1: counterclockwise
    , speed: 1 // Rounds per second
    , trail: 46 // Afterglow percentage
    , fps: 20 // Frames per second when using setTimeout() as a fallback for CSS
    , zIndex: 2e9 // The z-index (defaults to 2000000000)
    , className: 'spinner' // The CSS class to assign to the spinner
    , top: '50%' // Top position relative to parent
    , left: '50%' // Left position relative to parent
    , shadow: false // Whether to render a shadow
    , hwaccel: true // Whether to use hardware acceleration
    , position: 'absolute' // Element positioning
};

// options for tiny instance of Spinner
var smallOpts = {
    lines: 9 // The number of lines to draw
    , length: 6 // The length of each line
    , width: 3 // The line thickness
    , radius: 4 // The radius of the inner circle
    , scale: 1 // Scales overall size of the spinner
    , corners: 1 // Corner roundness (0..1)
    , color: '#000' // #rgb or #rrggbb or array of colors
    , opacity: 0.25 // Opacity of the lines
    , rotate: 0 // The rotation offset
    , direction: 1 // 1: clockwise, -1: counterclockwise
    , speed: 1 // Rounds per second
    , trail: 60 // Afterglow percentage
    , fps: 20 // Frames per second when using setTimeout() as a fallback for CSS
    , zIndex: 2e9 // The z-index (defaults to 2000000000)
    , className: 'spinner' // The CSS class to assign to the spinner
    , top: '50%' // Top position relative to parent
    , left: '50%' // Left position relative to parent
    , shadow: false // Whether to render a shadow
    , hwaccel: false // Whether to use hardware acceleration
    , position: 'absolute' // Element positioning
}

var DEFAULT_COLORS = [
    '#1f77b4',  // muted blue
    '#ff7f0e',  // safety orange
    '#2ca02c',  // cooked asparagus green
    '#d62728',  // brick red
    '#9467bd',  // muted purple
    '#8c564b',  // chestnut brown
    '#e377c2',  // raspberry yogurt pink
    '#7f7f7f',  // middle gray
    '#bcbd22',  // curry yellow-green
    '#17becf'   // blue-teal
];

// launch spinner modal whenever someone clicks a survey link with a class of '.spin'
$(function () {
    $('.spin').on('click', function (event) {
        var target = document.getElementById($(event.target).attr('id'));
        var spinner = new Spinner(smallOpts).spin(target);
        // store spinner to stop later
        $(target).data('spinner', spinner);
    });
});

// check if there are blank text boxes or selects
function validateFields(selector) {
    var values = selector.map(function() {return $(this).val()}).get();
    return values.indexOf("") === -1;
}

// check if all checkboxes are checked
function validateChecks(selector) {
    var values = selector.map(function() {return $(this).prop('checked')}).get();
    return values.indexOf(false) === -1;
}

// check if at least one radio is selected in a group
function validateRadios(selector) {
    var values = selector.map(function() {return $(this).prop('checked')}).get();
    return values.indexOf(true) >= 0;
}

// set error state for items that have a property of 'checked' == false
function setErrorOnChecked(selector) {
    selector.map(function() {
        if ( !$(this).prop('checked') ) {
            $(this).parent().addClass('has-error has-feedback');
        } else {
            $(this).parent().removeClass('has-error has-feedback');
        }
    });
}

// set error state on blank text boxes or selects
function setErrorOnBlank(selector) {
    selector.map(function() {
        if ( $(this).val() == "" ) {
            $(this).parent().addClass('has-error has-feedback');
        } else {
            $(this).parent().removeClass('has-error has-feedback');
        }
    });
}

// custom event to trigger event only after user has stopped resizing the window
$(window).resize(function() {
    if(this.resizeTO) clearTimeout(this.resizeTO);
    this.resizeTO = setTimeout(function() {
        $(this).trigger('resizeEnd');
    }, 100);
});