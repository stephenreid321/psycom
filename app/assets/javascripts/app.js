
$(function () {

  $('input[type=text].slug').each(function () {
    var slug = $(this);
    var start_length = slug.val().length;
    var pos = $.inArray(this, $('input', this.form)) - 1;
    var title = $($('input', this.form).get(pos));
    slug.focus(function () {
      slug.data('focus', true);
    });
    title.keyup(function () {
      if (start_length == 0 && slug.data('focus') != true)
        slug.val(title.val().toLowerCase().replace(/ /g, '-').replace(/[^a-z0-9\-]/g, ''));
    });
  });

  function popover() {
    $('[data-toggle="popover"]').popover({
      html: true,
      viewport: false,
      trigger: 'manual',
      placement: 'top',
      animation: false,
      title: function () {
        return $(this).next('span').html()
      },
      content: function () {
        return $(this).next('span').next('span').html()
      }
    }).on("mouseenter", function () {
      var _this = this;
      setTimeout(function () {
        if ($(_this).filter(':hover').length) {
          $(_this).popover("show");
          $($(_this).data('bs.popover')['tip']).on("mouseleave", function () {
            $(_this).popover('hide');
          });
        }
      }, 200);
    }).on("mouseleave", function () {
      var _this = this;
      setTimeout(function () {
        if (!$($(_this).data('bs.popover')['tip']).filter(':hover').length) {
          $(_this).popover("hide");
        }
      }, 200);
    });
  }

  function tooltip() {
    $('[data-toggle="tooltip"]').tooltip({
      html: true,
      viewport: false,
      title: function () {
        if ($(this).attr('title').length > 0)
          return $(this).attr('title')
        else
          return $(this).next('span').html()
      }
    })
  }

  function timeago() {
    $("abbr.timeago").timeago()
  }

  function wysify() {
    $('textarea.wysiwyg').each(function () {
      var textarea = this
      var editor = textboxio.replace(textarea, {
        css: {
          stylesheets: ['/stylesheets/app.css']
        },
        paste: {
          style: 'plain'
        },
        images: {
          allowLocal: false
        }
      });
      if (textarea.form)
        $(textarea.form).submit(function () {
          if ($(editor.content.get()).text().trim() == '')
            $(textarea).val(' ')
        })
    });
  }

  function datepickers() {
    $(".datepicker").flatpickr({altInput: true, altFormat: 'J F Y'});
    $(".datetimepicker").flatpickr({altInput: true, altFormat: 'J F Y, H:i', enableTime: true, time_24hr: true});
  }

  $(document).ajaxComplete(function () {
    wysify()
    popover()
    tooltip()
    timeago()
    datepickers()
  });
  wysify()
  popover()
  tooltip()
  timeago()
  datepickers()



  $(document).on('click', '.page-container .pagination a', function (e) {
    if ($(this).attr('href') != '#') {
      $(this).closest('.page-container').load($(this).attr('href'), function () {
        scroll(0, 0);
      });
    }
    return false;
  });

  $(document).on('click', 'a.modal-trigger', function (e) {
    $('#modal .modal-content').load(this.href, function () {
      $('#modal').modal('show');
    });
    return false;
  });

  $('form').submit(function () {
    $('button[type=submit]', this).attr('disabled', 'disabled').html('Submitting...');
  });

  $('a[data-toggle="tab"]').on('show.bs.tab', function (e) {
    $('.fc-event').popover('destroy');
  });

  Array.prototype.unique = function () {
    var unique = [];
    for (var i = 0; i < this.length; i++) {
      if (unique.indexOf(this[i]) == -1) {
        unique.push(this[i]);
      }
    }
    return unique;
  };

  $(document).on('click', 'a[data-confirm]', function (e) {
    var message = $(this).data('confirm');
    if (!confirm(message)) {
      e.preventDefault();
      e.stopped = true;
    }
  });

  $(document).on('change', 'input[type=file]', function (e) {
    if (typeof FileReader !== "undefined") {
      var file = this.files[0]
      if (file) {
        var size = file.size;
        if (size > 5 * 1024 * 1024) {
          alert("That file exceeds the maximum attachment size of 5MB. Upload it elsewhere and include a link to it instead.")
          $(this).val('');
        }
      }
    }
  });

  $('.geopicker').geopicker({
    width: '100%',
    getLatLng: function (container) {
      var lat = $('input[name$="[lat]"]', container).val()
      var lng = $('input[name$="[lng]"]', container).val()
      if (lat.length && lng.length)
        return new google.maps.LatLng(lat, lng)
    },
    set: function (container, latLng) {
      $('input[name$="[lat]"]', container).val(latLng.lat());
      $('input[name$="[lng]"]', container).val(latLng.lng());
    }
  });

  $(document).on('click', 'a.popup', function (e) {
    window.open(this.href, null, 'scrollbars=yes,width=600,height=600,left=150,top=150').focus();
    return false;
  });

  $('#results-form').submit(function (e) {
    e.preventDefault();
    $('#filter-spin').show();
    $('#results').load($(this).attr('action') + '?' + $(this).serialize(), function () {
      $('#filter-spin').hide();
    });
  });

  $('#results-form input[type=radio], #results-form select, #results-form input[type=checkbox]').change(function () {
    $(this.form).submit();
  });

  $('#results-form').submit();

  if ($('th[data-fieldname]').length > 0) {
    var params = $.deparam(location.href.split('?')[1] || '');
    $('th').hover(function () {
      $('a.odn', this).css('visibility', 'visible')
    }, function () {
      $('a.odn', this).css('visibility', 'hidden')
    });
    $('a.od').click(function () {
      params['o'] = $(this).closest('th').data('fieldname')
      params['d'] = params['d'] == 'asc' ? 'desc' : 'asc'
      location.assign(location.pathname + '?' + $.param(params));
    });
  }

});
