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
//= require ckeditor/init
//= require dataTables/jquery.dataTables
//= require dataTables/bootstrap/3/jquery.dataTables.bootstrap
//= require spin.min
//= require_tree .

// toggle chevron glyphs on clicks
function toggleGlyph(el) {
    el.toggleClass('fa-chevron-right fa-chevron-down');
}

// attach various handlers to bootstrap items and turn on functionality
$(function() {
    $('.panel-heading').click(function () {
        var anchor = $(this).find('a');
        $(anchor)[0].click();
    });

    $('.panel-collapse').on('show.bs.collapse', function (e) {
        toggleGlyph($(this).prev().find('span.fa'));
    });

    $('.panel-collapse').on('hide.bs.collapse', function (e) {
        toggleGlyph($(this).prev().find('span.fa'));
    });

    $('[data-toggle="tooltip"]').tooltip();
    $('[data-toggle="popover"]').popover();
});

// toggle the Search/View options panel
function toggleSearch() {
    $('#search-target').toggleClass('col-md-3 hidden');
    $('#render-target').toggleClass('col-md-9 col-md-12');
    $('#search-options-panel').toggleClass('hidden');
    $('#show-search-options').toggleClass('hidden');
    if ( $('#show-search-options').css('display') == 'none' ) {
        $('#show-search-options').tooltip('hide');
    }
    // trigger resizeEnd to re-render Plotly to use available space
    setTimeout(function() {
        $(window).trigger('resizeEnd');
    }, 100);
}

// options for Spin.js
var opts = {
    lines: 13 // The ~number of lines to draw
    , length: 56 // The length of each line
    , width: 14 // The line thickness
    , radius: 42 // The radius of the inner circle
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
};

// default title font settings for axis titles in plotly
var plotlyTitleFont = {
    family: 'Helvetica Neue',
    size: 16,
    color: '#333'
};

// default label font settings for colorbar titles in plotly
var plotlyLabelFont = {
    family: 'Helvetica Neue',
    size: 12,
    color: '#333'
};

// scatter plot background color when not showing expression values
var plotlyDefaultBgColor = '#ddd';

// default scatter plot colors, a combination of colorbrewer sets 1-3 with small adjustments to yellow colors
var colorBrewerSet = ["#e41a1c","#377eb8","#4daf4a","#984ea3","#ff7f00","#f2f20f","#a65628","#f781bf","#999999","#66c2a5","#fc8d62","#8da0cb","#e78ac3","#a6d854","#ffd92f","#e5c494","#b3b3b3","#8dd3c7","#ebeba5","#bebada","#fb8072","#80b1d3","#fdb462","#b3de69","#fccde5","#d9d9d9","#bc80bd","#ccebc5","#ffed6f"];


// clear out text area in a form
function clearForm(target) {
    $('#' + target).val("");
}

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

// custom event to trigger resize event only after user has stopped resizing the window
$(window).resize(function() {
    if(this.resizeTO) clearTimeout(this.resizeTO);
    this.resizeTO = setTimeout(function() {
        $(this).trigger('resizeEnd');
        console.log('resizeEnd');
    }, 100);
});

// generic function to render Morpheus
function renderMorpheus(dataPath, annotPath, target, fitType) {
    var config = {dataset: dataPath};

    // fit rows, columns, or both to screen
    if (fitType == 'cols') {
        config.columnSize = 'fit';
    } else if (fitType == 'rows') {
        config.rowSize = 'fit';
    } else if (fitType == 'both') {
        config.columnSize = 'fit';
        config.rowSize = 'fit';
    }

    // load annotations if specified
    if (annotPath != '') {
        config.columnAnnotations = [{
            file : annotPath,
            datasetField : 'id',
            fileField : 'CELL_NAME'}
        ];
        config.columnSortBy = [
            {field:'CLUSTER', order:0},
            {field:'SUB-CLUSTER', order:0}
        ];
    }

    // instantiate heatmap and embed in DOM element
    var heatmap = new morpheus.HeatMap(config);
    $(target).html(heatmap.$el);
}

