$(function() {  
  var $ = jQuery,
      
      // utility
      urlQuery = {},
      now = new Date(),
      daysBetween,
      weekdaysBetween,
      
      // utilization colors
      interpolateColor,
      UTIL_CUTOFFS = [
        0, 100
        //0, 25, 50, 75, 100
      ],
      UTIL_COLORS = [
        /*[255, 255, 255],
        [0,   227, 227],
        [0,   227, 87 ],
        [229, 255, 0  ],
        [255, 169, 0]*/
        [255, 255, 255],
        [204, 108, 0]
      ],
      
      EventManager,
      isArray = Array.isArray,
      fill,
      
      // constants
      DEFAULT_MONTHS_TO_SHOW = 4,
      DURATION = {},
      
      // chart objects
      GanttChart,
      GanttDateCell,
      GanttDateCellMarker,
      GanttSection,
      GanttResourceRow,
      GanttAssignmentRow,
      
      // data
      resources,      
      assignments,    // array of arrays of assignments (in same order as resources)
      
      // initialize chart
      initializeChart,
      
      // dom stuff and chart instance
      chartContainer = $("#chart-container"),
      chart;
  
  // calculate common durations for convenience later
  DURATION.hour = Date.UTC(0, 0, 1, 1) - Date.UTC(0, 0, 1, 0);
  DURATION.day = DURATION.hour * 24;
  DURATION.week = DURATION.day * 7;
  DURATION.month30 = DURATION.day * 30;
  DURATION.year = DURATION.day * 365;
  
  // decode the url query, if there was any
  (function() {
    var query = window.location.href.split("?")[1];
    
    // if there was a query string
    if( query ) {
      // remove any funky %## stuff the URL might contain
      query = decodeURIComponent(query);
      
      // split at ampersands, then for each key-value pair...
      query.split("&").forEach(function( param ) {
        // ... split at '=' to separate key/value
        param = param.split("=");
        
        // save the pair in the urlQuery object
        urlQuery[param[0]] = param[1];
      });
    }
  }());
  
  // modify the Date prototype
  Date.prototype.startOfUTCMonth = function Date_startOfUTCMonth() {
    return new Date(Date.UTC(
      this.getUTCFullYear(),
      this.getUTCMonth(),
      1
    ));
  };
  
  Date.prototype.startOfUTCDay = function Date_startOfUTCDay() {
    return new Date(Date.UTC(
      this.getUTCFullYear(),
      this.getUTCMonth(),
      this.getUTCDate()
    ));
  };
  
  Date.prototype.getUTCMonthName = function Date_getUTCMonthName() {
    return [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ][ this.getUTCMonth() ];
  };
  
  Date.prototype.getUTCDayName = function Date_getUTCDayName() {
    return [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday"
    ][ this.getUTCDay() ];
  };
  
  Date.prototype.niceUTCString = function Date_niceUTCString() {
    return this.getUTCDayName() + ", " + this.getUTCMonthName() + " " + this.getUTCDate() + ", " + this.getUTCFullYear();
  };
  
  daysBetween = function daysBetween( start, end ) {
    var days = 0;
    
    // make sure start is a date, end is a utc time
    (start = new Date(start)).setUTCHours(0, 0, 0, 0);
    end = new Date(end).setUTCHours(0, 0, 0, 0);
    
    while(start.valueOf() < end) {
      // while the end hasn't been reached, increment days and move to next day
      days++;
      start.setUTCDate(start.getUTCDate() + 1);
    }
    
    return days;
  };
  
  weekdaysBetween = function weekdaysBetween( start, end ) {
    var weekdays = 0,
        day;
    
    // make sure start is date, end is utc
    (start = new Date(start)).setUTCHours(0, 0, 0, 0);
    end = new Date(end).setUTCHours(0, 0, 0, 0);
    
    while(start.valueOf() <= end) {
      // if day of week is not Sunday (0) or Saturday (6)
      day = start.getUTCDay();
      if(day > 0 && day < 6) {
        // increment num weekdays
        weekdays++;
      }
      
      // move to next day
      start.setUTCDate(start.getUTCDate() + 1);
    }
    
    return weekdays;
  };
  
  /** 
   * Used to determine what color the utilization bars should be.
   *   assumes cutoffs and colors are arrays
   *   assumes all elements in cutoffs are numbers between 0 and 100
   *   assumes each element in cutoffs is greater than the one before it
   *   assumes all elements in colors are arrays with 3 or 4 elements, all of which are numbers between 0 and 255
   *   assumes cutoffs.length === colors.length
   *   assumes percent is a number between 0 and 100
   */
  interpolateColor = function interpolateColor( cutoffs, colors, percent ) {
    var i = 0,
        color = [],
        startOff, stopOff,
        start, stop;
    
    // while percent is after the cutoff
    while( i < cutoffs.length && cutoffs[i] < percent ) i++;
    
    // get the color
    if( i === 0 || cutoffs[i] === percent ) {
      //console.log("Just using first color");
      // just the first color
      color[0] = colors[i][0];
      color[1] = colors[i][1];
      color[2] = colors[i][2];
      color[3] = colors[i].length === 4 ? colors[i][3] : 255;
    } else if( i === cutoffs.length ) {
      i--;
      
      // just the last color
      color[0] = colors[i][0];
      color[1] = colors[i][1];
      color[2] = colors[i][2];
      color[3] = colors[i].length === 4 ? colors[i][3] : 255;
    } else {
      
      
      // interpolate between the two colors
      start = colors[i - 1];
      startOff = cutoffs[i - 1];
      stop = colors[i];
      stopOff = cutoffs[i];
      
      // redo the percent to be between the two colors
      percent = (percent - startOff) / (stopOff - startOff);
      
      // make sure there's alpha
      start.length === 4 || (start[3] = 255);
      stop.length === 4 || (stop[3] = 255);
      
      for(i = 0; i < 4; i++) {
        color[i] = Math.round(start[i] + (stop[i] - start[i]) * percent);
      }
    }
    
    color.rgb = "rgb(" + color[0] + ", " + color[1] + ", " + color[2] + ")";
    color.rgba = "rgba(" + color[0] + ", " + color[1] + ", " + color[2] + ", " + color[3] + ")";
    
    return color;
  };
  
  /**
   * Use "new EventManager()" when calling this function.
   * This creates an object capable of holding listeners and firing events.
   * The 'on' function of the created object is used to add listeners to certain event types, and the 'fire'
   * function is used to send certain information to those listeners. For example:
   * 
   * var em = new EventManager();
   * 
   * // listen for a 'myEvent' event
   * em.on("myEvent", function( eventData ) { console.log(eventData.name); });
   * 
   * // fire a 'myEvent' event with data
   * em.fire("myEvent", { name: "Who?" });
   * 
   * In the previous example, the string "Who?" would be logged to the console.
   * 
   * Having this function as a separate object has many advantages:
   *  1) The purpose of on(), off(), and fire() is more clear
   *  2) Using the fill() function (see below), the ability to manage events can be added to any object
   *  3) The behavior of any objects that are event managers or use event manager can instantly be changed
   *     through one central function
   */
  EventManager = function EventManager( context ) {
    this._callbacks = {};
    this.context = context;
  };
  
  EventManager.prototype = {
    allowedNames: /[A-Za-z]+/,
    
    /**
     * Adds a listener to this event manager. The listener will be called whenever an event of
     * one of the given types is fired on this event manager.
     */
    on: function EventManager_on( types, callback ) {
      var callbacks = this._callbacks,
          allowedNames = this.allowedNames;
      
      // make sure the callback is a function
      if( typeof callback !== "function" ) {
        return;
      }
      
      // string type names should be parsed into array
      if( typeof types === "string" ) {
        types = types.split(/\s+/);
      }
      
      // if types not an array now, do nothing
      if( !isArray(types) ) {
        return;
      }
      
      // add the callback to each of the specified types (if a function and not already in list)
      types.forEach(function( type ) {
        var cbArray;
        
        // if type contains only letters (at least one)
        if( allowedNames.test(type) ) {
          // make sure array exists
          if( !(cbArray = callbacks[type]) ) {
            cbArray = callbacks[type] = [];
          }
          
          // if not already present, add the callback
          if( cbArray.indexOf(callback) === -1 ) {
            cbArray.push(callback);
          }
        }
      });
      
      return this;
    },
    
    /**
     * Removes a callback (or multiple callbacks) from the event manager. If just a function is given,
     * all occurrences of that callback are removed. If just a string or array is given, all of the listeners
     * for events of the types specified by the string (space-separated type names) or array are removed. If
     * both a (string or array) and (callback) are given, the given callback is only removed from the given
     * types, if it exists there.
     */
    off: function EventManager_off( types, callback ) {
      var type, cbArray, index,
          callbacks = this._callbacks,
          allowedNames = this.allowedNames;
      
      if( arguments.length === 1 && typeof types === "function" ) {
        // just a function to remove, don't need to parse types
        callback = types;
        types = undefined;
      } else {
        // if no callback, mark as false
        if( typeof callback !== "function" ) {
          callback = false;
        }
        
        // string type names should be parsed into array
        if( typeof types === "string" ) {
          types = types.split(/\s+/);
        }
        
        // if types not an array now, do nothing
        if( !isArray(types) ) {
          return;
        }
      }
      
      if( types ) {
        // filter out empty / invalid type names
        types.filter(function( type ) {
          return allowedNames.test(type);
        });
        
        types.forEach(callback ? 
        
        // callback given, just remove that callback
        function( type ) {
          cbArray = callbacks[type];
          // if there is an array for that type, AND it contains the given callback
          if( cbArray && (index = cbArray.indexOf(callback), index !== -1) ) {
            // then remove that callback
            cbArray.splice(index, 1);
          }
        } :
        
        // no callback given, remove all listeners for that type
        function( type ) {
          callbacks[type] = [];
        });
      } else {
        // no specific types given, so remove all occurrences of the given callback
        for( type in callbacks ) {
          cbArray = callbacks[type];
          // if the array contains the callback...
          if( index = cbArray.indexOf(callback), index !== -1 ) {
            // ...remove it
            cbArray.splice(index, 1);
          }
        }
      }
      
      return this;
    },
    
    /**
     * Calls all of the handlers for the given event type, in the order they were added to the event manager.
     * Each handler is passed the given data as its only argument. If the EventManager constructor was passed
     * an argument ('context'), then within the handlers 'this' will refer to that object.
     */
    fire: function EventManager_fire( type, data ) {
      var errors = [],
          cbArray = this._callbacks[type],
          context = this.context,
          contextIsFn = typeof context === "function";
      
      // if no callback array, quit
      if( !cbArray ) {
        return;
      }
      
      cbArray.forEach(function( callback ) {
        try {
          if( context ) {
            callback.call(contextIsFn ? context() : context, data);
          } else {
            callback(data);
          }
        } catch(e) {
          errors.push(e);
        }
      });
      
      if( errors.length > 0 ) {
        //console.log("Silenced " + errors.length + " error(s) during firing of '" + type + "' event:\n  "
                //+ errors.join("\n  "));
      }
      
      return this;
    }
  };
  
  /**
   * For each key-value pair found in the object 'defs', this function fills the value into the object 'obj' if
   * 'obj' does not already possess a value for the corresponding key.
   * 
   * @param {object} obj   The object whose properties should be filled
   * @param {object} defs  The key-value pairs to fill into obj
   * 
   * @returns {object}  The mutated object obj
   */
  fill = function fill( obj, defs ) {
    // for each property in defs ...
    for( var prop in defs ) {
      // ... if the property is not in obj ...
      if( !(prop in obj) ) {
        // ... fill in the value from defs!
        obj[prop] = defs[prop];
      }
    }
    
    return obj;
  };
  
  /**
   * Parent object providing a complete representation of the data and HTML elements underlying the chart.
   */
  GanttChart = function GanttChart() {
    var i;
    
    // add event managing functionality to the chart
    fill(this, new EventManager());
    
    // the starting date of the gantt chart, as a UTC time
    this.startUTC = "start" in urlQuery ? 
      
      // if a start date was found in the url query, use it
      (new Date(+urlQuery.start)).valueOf() : 
      
      // otherwise, use the start of this month
      now.startOfUTCMonth().valueOf();
      
    // the ending date of the gantt chart, as a UTC time
    this.endUTC = "end" in urlQuery ? 
      
      // if end date was in the query, use it
      (new Date(+urlQuery.end)).valueOf() :
      
      // otherwise, determine end date based off start and DEFAULT_MONTHS_TO_SHOW
      (function() {
        var year = now.getUTCFullYear(),
            month = now.getUTCMonth(),
            monthsToGo = DEFAULT_MONTHS_TO_SHOW;
        
        // add as many years as possible (integer division rounds down)
        year += monthsToGo / 12;
        
        // get the remaining months
        monthsToGo %= 12;
        
        // add the additional months to the current month
        if((month += monthsToGo) > 11) {
          // if the remaining months push the date into the next year,
          // add one to the year and subtract the twelve months from the month
          year += 1;
          month -= 12;
        }
        
        // get the UTC time for the end date!
        return Date.UTC(year, month, 1);
      }());
    
    // the HTML <table> that contains the chart
    this.table = $("<table />")
      .addClass("de-gantt-chart");
    
    // a reference to the chart's date cell (the top right cell with the markers)
    this.dateCell = new GanttDateCell(this);
    
    // a list of the sections of the chart (each resource has one section)
    this.sections = [];
    
    // add the first row
    this.table.append(
      $("<tr />")
        .addClass("de-gantt-date-row")
        .append("<th>Date</th>")
        .append(this.dateCell.td)
    );
    
    // for each resource
    for(i = 0; i < resources.length; i++) {
      // create the section for that resource
      var section = new GanttSection(this, resources[i], assignments[i]);
      
      // add the section to the list, add its 'header' row to the table
      this.sections.push(section);
      this.table.append(section.resourceRow.tr);
      
      // for each assignment row, add it to the table too
      section.rows.forEach(function( row ) {
        this.table.append(row.tr);
      }, this);
    }
  };
  
  GanttChart.prototype = {
    /**
     * Updates the start and end dates of the chart, causing everything to be repositioned with respect
     * to the new bounds.
     */
    setDates: function GanttChart_setDates( newStart, newEnd ) {
      var oldStart = this.startUTC,
          oldEnd = this.endUTC;
      
      this.startUTC = newStart || this.startUTC;
      this.endUTC = newEnd || this.endUTC;
      
      // fire an update event
      this.fire("dateChange", {
        oldStart: oldStart,
        oldEnd:   oldEnd,
        newStart: this.startUTC,
        newEnd:   this.endUTC
      });
      
      this.update();
    },
    
    /**
     * This function MUST be called as soon as possible once the chart becomes visible. It solidifies the
     * width of the chart (to prevent it from slowly expanding to the right) and sets the height of table
     * cells so Firefox and IE will properly size the assignment bars.
     * 
     * WARNING: Calling this before the chart is visible will cause improper dimensions to be set, and will
     * prevent the chart from being displayed properly.
     * 
     * ANOTHER WARNING: Calling this function AFTER a call to .update() has occurred may cause some rows to
     * have incorrect heights set, since .update() hides rows whose assignment's aren't visible (as a result,
     * those rows will have their height set to 0).
     */
    determineDimensions: function GanttChart_determineDimensions() {
      this.width = this.dateCell.td.outerWidth();
      //console.log("Assigned width of " + this.width);
      
      // ie and firefox don't size % heights unless the parent has an explicit value
      // so, for them, set that value now
      this.sections.forEach(function( section ) {
        section.rows.forEach(function( assignmentRow ) {
          var td = assignmentRow.bodyCell;
          
          td.outerHeight(td.outerHeight());
        });
      });
    },
    
    /**
     * This function verifies the start and end UTC times refer to midnight of a UTC day (that is, the dates
     * have no time parts). Then, the ratio of pixels per day is recalculated (critical to the sizing and
     * positioning of nearly every chart component. Finally, the chart notifies its subcomponents (date cell
     * and sections) of the update by calling their respective .update() methods.
     */
    update: function GanttChart_update() {
      // make sure start / end UTCs have no time parts
      this.startUTC = (new Date(this.startUTC)).setUTCHours(0, 0, 0, 0);
      this.endUTC = (new Date(this.endUTC)).setUTCHours(0, 0, 0, 0);
      //console.log("Using UTC time range " + this.startUTC + " to " + this.endUTC);
      
      // recalculate day density
      this.pixelsPerDay = this.width / daysBetween(this.startUTC, this.endUTC);
      
      // update componenets
      this.dateCell.updateMarkers();
      this.sections.forEach(function( section ) {
        section.update();
      });
    },
    
    /**
     * Given an x-coordinate on the chart ('xCoord'), this function returns a Date nearest to that
     * coordinate on the chart. If 'snapToDay' is true, the returned Date is instead rounded to the nearest
     * UTC midnight time (useful for snapping gridlines to day start times).
     */
    dateFor: function GanttChart_dateFor( xCoord, snapToDay ) {
      var frac, date, below, above;
      
      // if the x coordinate isn't a number, don't bother
      if( isNaN(xCoord) ) {
        return;
      }
      
      // otherwise, convert the x coordinate to a fraction of the chart width
      xCoord = +xCoord;
      frac = Math.max(
        0, Math.min(        // at least 0
        1,                  // at most 1
        xCoord / this.width // fraction of xCoord from 0 to this.width
      ));
      
      // construct a new date from the fraction
      date = new Date( this.startUTC + (this.endUTC - this.startUTC) * frac );
      
      if( snapToDay ) {
        // snap to CLOSER day, not just round down
        date = date.valueOf();
        
        // get the previous and upcoming midnight times
        below = new Date(date).setUTCHours(0, 0, 0, 0);
        above = new Date(below);
        above.setUTCDate(above.getUTCDate() + 1);
        above = above.setUTCHours(0, 0, 0, 0);
        
        // if below is closer, use it; otherwise, use above
        date = ( date - below < above - date ) ?
          below : above;
        
        // make sure it's a Date
        date = new Date(date);
      }
      
      return date;
    },
    
    /**
     * Given a UTC time, this function returns the x-coordinate of that time within the context of the chart's
     * start and end dates. If 'snapToDay' is true, the given UTC time is first rounded to the nearest UTC
     * midnight before it is used to determine the appropriate x-coordinate.
     */
    xCoordFor: function GanttChart_xCoordFor( utc, snapToDay ) {
      var below, above;
      
      // if a Date was given, get its utc time
      if( utc instanceof Date ) {
        utc = utc.valueOf();
      }
      
      // if not a number, just don't
      if( isNaN(utc) ) {
        return;
      }
      
      // coerce into number ( isNaN() returns false if given a string like "2.4",
      // but doing +"2.4" results in the number 2.4)
      utc = +utc;
      
      if( snapToDay ) {
        // snap to CLOSER day, not just round down
        below = new Date(utc).setUTCHours(0, 0, 0, 0);
        above = new Date(below);
        above.setUTCDate(above.getUTCDate() + 1);
        above = above.setUTCHours(0, 0, 0, 0);
        
        // if below is closer, use it; otherwise, use above
        utc = ( utc - below < above - utc ) ?
          below : above;
      }
      
      // multiply the chart width by the fraction of the given date in the chart's date range
      return this.width * ( (utc - this.startUTC) / (this.endUTC - this.startUTC) );
    }
  };
  
  /**
   * Object responsible for managing the date markers and hovering-tooltips in the top-right cell of the chart.
   */
  GanttDateCell = function GanttDateCell( chart ) {
    var dateTooltip, dateLine; // internal references
    
    // reference to parent chart
    this.chart = chart;
    
    // date markers (the little "ticks" that appear at the top)
    //   see GanttDateCellMarker below
    this.markers = [];
    
    // the mouse-hover date marker (shows up when user hovers over the date cell)
    // have to use internal reference for jQuery callbacks
    // because jQuery changes 'this' to the element
    dateTooltip = this.dateTooltip = $("<div />")
      .css({
        "position": "absolute",
        "display": "none"
      })
      .addClass("de-gantt-date-tooltip");
    
    // the vertical line that appears when the user hovers over the date cell
    dateLine = this.dateLine = $("<div />")
      .css({
        "position": "absolute",
        "top": 0,
        "display": "none"
      })
      .addClass("de-gantt-date-line");
    
    // the actual table cell appearing in the chart
    this.td = $("<td />")
      .css("position", "relative")
      .addClass("de-gantt-date")
      .append(dateTooltip)
      .append(dateLine)
      
      // when the mouse enters the cell, show the date tooltip
      // when it leaves, hide the tooltip
      .hover(function() {
        dateTooltip.css("display", "block");
        dateLine.css("display", "block");
        
        // showing of resource row tooltips is done in the mousemove callback below
      }, function() {
        dateTooltip.css("display", "none");
        dateLine.css("display", "none");
        
        // hide the resource rows' tooltips
        chart.sections.forEach(function( section ) {
          section.resourceRow.hideTooltip();
        });
      })
      
      // when the mouse moves over the cell, indicate the date the mouse is on
      .mousemove(function( ev ) {
        var t = $(this),
            xCoord,
            date, width;
        
        // for IE, use the silly window.event
        ev = window.event || ev;
        xCoord = ev.clientX - t.offset().left;
        
        // first, get the date corresponding to the event's x coordinate
        date = chart.dateFor(xCoord, true);
        
        // change the tooltip's text to the new date
        dateTooltip
          .css("left", 0)  // temporary, to fix annoying resizing
          .html( date.niceUTCString() );
        
        // get the new width of the tooltip, then position it (ensuring it doesn't go off the screen)
        width = dateTooltip.outerWidth();
        dateTooltip.css({
          "left": Math.min(
            xCoord - width / 2,     // hopefully use this one (centered on the mouse position)
            chart.width - width - 5 // but don't overflow (stacked against right edge with a little padding)
          ),
          "top": (t.outerHeight() - dateTooltip.outerHeight()) / 2
        });
        
        // now move and size the date line
        dateLine.css({
          "left": (xCoord = chart.xCoordFor(date.valueOf(), true)),
          "height": chart.table.outerHeight()
        });
        
        // finally, show resource row tooltips
        chart.sections.forEach(function( section ) {
          section.resourceRow.showTooltip(xCoord);
        });
      });
  };
  
  GanttDateCell.prototype = {
    /**
     * This method is called by .update() to determine what markers should be added to the date cell.
     * 
     * IMPORTANT: The content of this method CAN BE EDITED if you want to change what dates are marked in
     * various scenarios. Do not alter initial variable declarations or the return statement, but any if
     * statements can be changed.
     * 
     * If you decide to add a new tier or change an existing one, understand how the return object 'ret' is
     * used before modifying anything:
     *   ret.name    Should be a string -- a unique name for this increment
     *   ret.start   MUST be a Date object -- the Date of the first marker to show
     *   ret.next    MUST be a function, MUST return a date, shouldn't modify the original date
     *               -- within the .update() method, this function is passed the date of the previous marker,
     *               and should return the date of the next marker to display. The function does not need to
     *               check if the returned date is out of range; the .update() function will handle that.
     *   ret.format  MUST be a function, should return a string -- the .update() method passes dates to this
     *               function and uses the returned string as the html content of the marker.
     */
    determineIncrement: function GanttDateCell_determineIncrement() {
      var utcRange = this.chart.endUTC - this.chart.startUTC,
          date = new Date(this.chart.startUTC),
          ret = {};
      
      if(utcRange < DURATION.day * 14) {
        // range is less than two weeks, show days
        ret.name = "Days";
        ret.start = date;
        ret.next = function( date ) {
          // just return the next day
          var d = new Date(date);
          d.setUTCDate(date.getUTCDate() + 1);
          return d;
        };
        ret.format = function( date ) {
          return date.getUTCDayName() + "<br />" + date.getUTCMonthName() + " " + date.getUTCDate()
            + (date.getUTCMonth() === 0 && date.getUTCDate() === 1 ? "<br /><strong>" + date.getUTCFullYear() + "</strong>" : "");
        };
      } else if(utcRange < DURATION.month30) {
        // range is less than 30 days, show weeks
        ret.name = "Weeks";
        (ret.start = date).setUTCDate(date.getUTCDate() - date.getUTCDay());
        ret.next = function( date ) {
          // return the same day of the next week
          var d = new Date(date);
          d.setUTCDate(date.getUTCDate() + 7);
          return d;
        };
        ret.format = function( date ) {
          return date.getUTCDayName() + "<br />" + date.getUTCMonthName() + " " + date.getUTCDate()
            + (date.getUTCMonth() === 0 && date.getUTCDate() === 1 ? "<br /><strong>" + date.getUTCFullYear() + "</strong>" : "");
        };
      } else if(utcRange < DURATION.year) {
        // range is less than a year, show months
        ret.name = "Months";
        ret.start = date.startOfUTCMonth();
        ret.next = function( date ) {
          // return the start of the next month
          var d = new Date(date);
          d.setUTCMonth(date.getUTCMonth() + 1);
          return d;
        };
        ret.format = function( date ) {
          return "<strong>" + date.getUTCMonthName() + "</strong><br />" + date.getUTCFullYear();
        };
      } else {
        // show years
        ret.name = "Years";
        ret.start = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
        ret.next = function( date ) {
          // return the start of the next year
          var d = new Date(date);
          d.setUTCFullYear(date.getUTCFullYear() + 1);
          return d;
        };
        ret.format = function( date ) {
          return date.getUTCFullYear();
        };
      }
      
      /**
       *  ret.start  : Date           : The date at where the first marker should be (or where increments should be based off)
       *  ret.next   : Function(Date) : Callback used to determine the next increment from a given one
       *  ret.format : Function(Date) : Callback to convert a marker Date to an HTML string to associate with that marker
       */
      return ret;
    },
    
    /**
     * Removes old markers and determine what new markers should be shown.
     */
    updateMarkers: function GanttDateCell_updateMarkers() {
      var lastStart = this.lastStart, // start of the previous date range
          lastPPD = this.lastPixelsPerDay, // previous pixel:day ratio
          startUTC = this.chart.startUTC, // current start time
          endUTC = this.chart.endUTC, // current end time
          pixelsPerDay = this.chart.pixelsPerDay, // current pixel:day ratio
          increment = this.determineIncrement(), // increment to use (see .determineIncrement())
          date = increment.start, // date to use during iteration
          markers = this.markers, // reference to the markers currently in the date cell
          td = this.td; // reference to the HTML element of the date cell
      
      // animate each old marker to where it would be under the new time frame
      markers.forEach(function( marker ) {
        var newCenter = daysBetween(startUTC, marker.utc) * pixelsPerDay,
            width = marker.div.outerWidth();
        
        marker.div.stop().animate({
            "left": newCenter - width / 2,
            "opacity": 0
          },
          500,
          function() {
            marker.div.remove();
          }
        );
      });
      
      // done with old markers; forget them
      markers = this.markers = [];
      
      // determine what new markers should exist
      // while the current date is not at or past the end UTC time ...
      while(date.valueOf() <= endUTC) {
        //console.log("Checking UTC " + date.valueOf());
        if(date.valueOf() >= startUTC) {
          //console.log("   ...added!");
          markers.push(new GanttDateCellMarker(
            this,
            date.valueOf(),
            daysBetween(startUTC, date),
            increment.format(date)
          ));
        }
        //console.log("   ...trying new date " + increment.next(date));
        date = increment.next(date);
        //console.log("   ...new date is " + date.valueOf());
      }
      
      // add each marker to the cell, animate it to its spot
      markers.forEach(function( marker ) {
        var lastCenter = daysBetween(lastStart, marker.utc) * lastPPD,
            width;
        
        // append marker to <td>
        td.append(marker.div);
        
        // get the marker's width
        width = marker.div.outerWidth();
        
        // animate from position under previous constraints to next
        marker.div.css({
          "opacity": 0,
          "left": lastCenter - width / 2
        }).animate({
          "opacity": 1,
          "left": marker.dayOffset * pixelsPerDay - width / 2
        }, 500);
      }, this);
      
      // save these for the next call to .updateMarkers()
      this.lastStart = startUTC;
      this.lastPixelsPerDay = pixelsPerDay;
    }
  };
  
  /**
   * Represents a single marker to display in the top right cell of the chart.
   */
  GanttDateCellMarker = function GanttDateCellMarker( cell, utc, dayOffset, content ) {
    this.cell = cell;
    this.utc = utc;
    this.dayOffset = dayOffset;
    
    this.tick = $("<div />")
      //.css("position", "absolute")
      .addClass("de-gantt-date-marker-tick");
      
    this.div = $("<div />")
      .append(content)
      .append(this.tick)
      .css("position", "absolute")
      .addClass("de-gantt-date-marker");
  };
  
  /**
   * Encompasses all the assignment data and chart rows for a single resource.
   */
  GanttSection = function GanttSection( chart, resource, assignments ) {
    // references to parent chart and related data
    this.chart = chart;
    this.resource = resource;
    this.assignments = assignments;
    
    // the "header" row (so-to-speak) for this resource (has name and utilization summary)
    //   see GanttResourceRow below
    this.resourceRow = new GanttResourceRow(this, resource);
    
    // a list of rows, one for each assignment in the assignments array
    // each is an instance of GanttAssignmentRow (see below)
    this.rows = [];
    
    // indicates whether or not this section is collapsed (all rows hidden)
    this.collapsed = false;
    
    // for each assignment, add an assignment row to the section
    assignments.forEach(function( assignment ) {
      this.rows.push(new GanttAssignmentRow(this, assignment));
    }, this);
  };
  
  GanttSection.prototype = {
    /**
     * Updates this section's resource ("header") row and each of its assignment rows.
     */
    update: function GanttSection_update() {
      this.resourceRow.update();
      this.rows.forEach(function( row ) {
        row.update();
      });
    },
    
    /**
     * Collapses this section (if it is not already collapsed), removing all of its assignment rows
     * from the table.
     */
    collapse: function GanttSection_collapse() {
      if(this.collapsed) {
        return; // already collapsed
      }
      
      this.rows.forEach(function( row ) {
        // only detach if row is not hidden
        !row.hidden && row.tr.detach();
      });
      this.resourceRow.tr.addClass("collapsed");
      this.collapsed = true;
    },
    
    /**
     * 
     * Expands this section (if it is not already expanded), showing all assignment rows that aren't hidden.
     */
    expand: function GanttSection_expand() {
      if(!this.collapsed) {
        return; // already expanded
      }
      
      this.rows.reduce(function( previousRow, currentRow ) {
        if(currentRow.hidden) {
          // if the current row is hidden, don't add it and return the previous row
          return previousRow;
        } else {
          // otherwise, add the current row and return it
          currentRow.tr.insertAfter(previousRow);
          currentRow.update();
          return currentRow.tr;
        }
      }, this.resourceRow.tr);
      
      // remove tagging class
      this.resourceRow.tr.removeClass("collapsed");
      
      // not collapsed anymore!
      this.collapsed = false;
    }
  };
  
  /**
   * Manages the "header" row for a resource.
   */
  GanttResourceRow = function GanttResourceRow( section, resource ) {
    var self = this; // a reference to this ResourceRow
    
    // references to parent section and resource data
    this.section = section;
    this.resource = resource;
    
    // added later by GanttResourceRow.prototype.update(), references the list of utility sections created
    // during the update process. This allows other code like showTooltip() to determine, for example, what
    // % utilized the resource is at a given x coordinate (in fact, this is exactly what showTooltip() does).
    this.utilSections;
    
    // <td> cell containing resource name
    this.nameCell = $("<td />")
      .text(resource.Name)
      .addClass("de-gantt-resource-name")
      
      // when clicked, collapse/expand this section (or all others if ctrl/meta is pressed)
      .click(function( evt ) {
        if(evt.metaKey || evt.ctrlKey) {
          // expand this, close all others
          section.expand();
          section.chart.sections.forEach(function( _section ) {
            if(_section !== section) {
              _section.collapse();
            }
          });
        } else {
          // if collapsed, expand; otherwise, collapse
          if(section.collapsed) {
            section.expand();
          } else {
            section.collapse();
          }
        }
      });
    
    // <div> where all the util-summary fun happens (colorful boxes next to each resource's name)
    this.bodyDiv = $("<div />")
      .addClass("de-gantt-resource-summary");
    
    // <div> popup that shows the % utilization for a resource
    this.utilTooltip = $("<div />")
      .css({
        "position": "absolute",
        "display": "none"
      })
      .addClass("de-gantt-util-tooltip");
    
    // vertical line that indicates the date when the cell is hovered over
    this.dateLine = $("<div />")
      .css({
        "position": "absolute",
        "top": 0,
        "display": "none"
      })
      .addClass("de-gantt-date-line");
    
    // <td> container for the bodyDiv
    this.bodyCell = $("<td />")
      .addClass("de-gantt-resource-body")
      .append(this.bodyDiv)
      .append(this.utilTooltip)
      .append(this.dateLine)
      .mousemove(function( ev ) {
        // when the mouse moves over the body cell, show the tooltip
        ev = window.event || ev;
        self.showTooltip( ev.clientX - $(this).offset().left, true );
      })
      .mouseleave(function() {
        // when the mouse leaves the body cell, hide the tooltip
        self.hideTooltip();
      });
    
    // the row containing the above two cells (nameCell and bodyCell)
    this.tr = $("<tr />")
      .append(this.nameCell)
      .append(this.bodyCell)
      .addClass("de-gantt-row de-gantt-resource");
  };
  
  GanttResourceRow.prototype = {
    /**
     * Calculates what colors and %s should be displayed where in this resource's utilization bar.
     * This process occurs in two main steps:
     *   1) Starting with a single initial section spanning the entire chart's view range, the section is
     *      split into however many subsections are necessary to accomodate all the assignments.
     *   2) The sections resulting from (1) are modified so their .start and .end properties are in terms
     *      of pixels offset from the left of the body cell, and a &lt;div&gt; is created to represent the
     *      section visually.
     */
    update: function GanttResourceRow_update() {
      var start = this.section.chart.startUTC,
          end = this.section.chart.endUTC,
          pixelsPerDay = this.section.chart.pixelsPerDay,
          assignments = this.section.assignments,
          assignmentRows = this.section.rows,
          sections = [{
            start: start,
            end: end,
            util: 0,
            assignments: []
          }],
          split;
      
      // index technically isn't necessary, but all the code that uses this
      // function will already know the index so it's more efficient to pass it
      // splits a section into two child sections at the given UTC time
      split = function split( index, time ) {
        var splitSection = sections[index],
            newSection = {
              start: time,
              end: splitSection.end,
              util: splitSection.util,
              assignments: []
            };
        
        splitSection.end = time;
        sections.splice(index + 1, 0, newSection); // insert new after current
      };
      
      // (step 1) iterate over the assignments -- this loop will divide sections and aggregate utilization
      // as needed to represent how utilized a resource is over the given time frame
      assignments.forEach(function( a, assignmentIndex ) {
        var aStart, aEnd,
            aUtil = a.utilization,
            sIndex, eIndex,
            index, add;
        
        // simple function called to add this assignment's utility to the current section
        // (determined by index), and add this assignment to the section's list
        add = function add() {
          sections[index].util += aUtil;
          sections[index].assignments.push( assignmentRows[assignmentIndex] ); // the whole row, not just assignment
        };
        
        // if start is after view end, or end is before view start, ignore this assignment
        if(a.Start_Date__c >= end || a.End_Date__c <= start) {
          return;
        }
        
        // otherwise, some part of the assignment must affect this view
        aStart = Math.max(a.Start_Date__c, start); // start should be no earlier than view start
        aEnd = Math.min(a.End_Date__c, end);     // end should be no later than view end
        
        // start at the first section, find the section to start at
        sIndex = 0;
        
        // while the assignment starts after the end of this section, move on
        while( aStart > sections[sIndex].end ) sIndex++;
        // now, sIndex is the index of the section containing the assignment's start date
        
        // now find the section to end at
        eIndex = sIndex;
        
        // while the assignment ends after the end of this section, move on
        while( aEnd > sections[eIndex].end ) eIndex++;
        
        // special case: start and end are same
        if(sIndex === eIndex) {
          index = sIndex;
          
          if(aStart !== sections[index].start) {
            // assignment starts after section start, so split (increment index to account for new section)
            split(index++, aStart);
          }
          
          if(aEnd !== sections[index].end) {
            // assignment ends before section end, so split (DON'T increment index)
            split(index, aEnd);
          }
          
          // add the utilization fraction to the relevant section
          add();
          
          return;
        }
        
        // if start and end indices are different, do the following:
        // first, check start section
        if(aStart !== sections[sIndex].start) {
          // aStart is after section start
          split(sIndex++, aStart);
          eIndex++;
          // increment indices to account for new section
        }
        
        // then, check final section
        if(aEnd !== sections[eIndex].end) {
          // aEnd is before section end
          split(eIndex, aEnd);
        }
        
        // last, start iteration over the sections to add util
        for(index = sIndex; index <= eIndex; index++) {
          add();
        }
      });
      
      // empty all the previous parts
      this.bodyDiv.empty();
      
      // now, for each section, convert its start / end into fractions
      // and add a <div> representing it
      sections.forEach(function( section, i ) {
        var div = $("<div />").addClass("de-gantt-resource-summary-chunk");
        
        section.div = div;
        section.start = daysBetween(start, section.start) * pixelsPerDay;
        section.end = daysBetween(start, section.end) * pixelsPerDay;
        
        div.css({
          "width": section.end - section.start,
          "background-color": interpolateColor( UTIL_CUTOFFS, UTIL_COLORS, section.util * 100 ).rgb
        });
        this.bodyDiv.append(div);
      }, this);
      
      // save a reference to the utilization sections (used by tooltips and stuff)
      this.utilSections = sections;
    },
    
    /**
     * Shows the tooltip for this row's section at the given x coordinate. If 'detailed' is set to true, then
     * the date is shown in the tooltip (in addition to the total utilization). In addition, utilization %s
     * for each assignment are shown when 'detailed' is true.
     */
    showTooltip: function GanttResourceRow_showTooltip( xCoord, detailed ) {
      var utilTooltip = this.utilTooltip, // quicker reference
              
          utilSections = this.utilSections, // same ^
          utilLen = utilSections.length, // number of sections
          index = 0, // index for iteration
          utilSection, // section containing the given x coordinate
          
          tooltipWidth, // width of the tooltip
          bodyCell = this.bodyCell, // quicker reference
          
          section = this.section, // same ^
          date = section.chart.dateFor(xCoord, true), // date for the given x coordinate
          snappedX = section.chart.xCoordFor(date, true), // xCoord rounded to nearest date
          height; // total height of the section (for date line)
      
      // show the tooltip
      utilTooltip.css("display", "block");
      
      // determine the appropriate section to use
      // while not at the last section, and the given coordinate is after the end of the current one
      while( index < utilLen - 1 && snappedX >= utilSections[index].end ) index++;
      
      // get the section
      utilSection = utilSections[index];
      
      // update the tooltip text and position
      utilTooltip
        .html(
          // if detailed, show the date
          ( detailed ? "<strong>" + date.niceUTCString() + "</strong><br />" : "" ) +
          
          // always show the %
          Math.round(utilSection.util * 100) + "%" 
        );
      
      // save the tooltip's width
      tooltipWidth = utilTooltip.outerWidth();
      utilTooltip.css({
        "left": Math.min(
          xCoord - tooltipWidth / 2,               // hopefully this (center on cursor)
          bodyCell.outerWidth() - tooltipWidth - 5 // but don't overflow (stack against right of page with padding)
        ),
        "top": (bodyCell.height() - utilTooltip.outerHeight()) / 2
      });
      
      // and, highlight all relevant assignments (unhighlight any unnecessary)
      // (first, get all the assignments that hit this section)
      utilSections = utilSection.assignments.map(function( a ) {
        // for each assignmentRow (section.assignments), return its assignment
        return a.assignment;
      });
      
      // (now, for each assignment row in this section, if it's assignment is
      // in the list above, add a highlight class; otherwise, remove that class)
      section.rows.forEach(function( row ) {
        var bar = row.assignmentBar;
        
        if( utilSections.indexOf(row.assignment) === -1 ) {
          bar.removeClass("date-highlight");
          
          if( detailed ) {
            // eventually, show % for this assignment (have yet to define .showTooltip( ))
            //row.showTooltip(snappedX);
          }
        } else {
          bar.addClass("date-highlight");
        }
      });
      
      // if detailed, show the date line
      if( detailed ) {
        // height is initially resource row height
        height = section.resourceRow.tr.innerHeight();
        
        // if not collapsed, add each row's height if not hidden
        if( !section.collapsed ) {
          section.rows.forEach(function( row ) {
            if( !row.hidden ) {
              height += row.tr.outerHeight();
            }
          });
        }
        
        // style the date line
        this.dateLine.css({
          "display": "block",
          "left": snappedX,
          "height": height
        });
      }
    },
    
    /**
     * Hides the row's tooltip.
     */
    hideTooltip: function GanttResourceRow_hideTooltip() {
      // hide the total util tooltip and date line
      this.utilTooltip.css("display", "none");
      this.dateLine.css("display", "none");
      
      // remove classes from all rows
      this.section.rows.forEach(function( row ) {
        //row.hideTooltip();
        row.assignmentBar.removeClass("date-highlight");
      });
    }
  };
  
  /**
   * Manages a row associated with a single assignment.
   */
  GanttAssignmentRow = function GanttAssignmentRow( section, assignment ) {
    var doSameProjectRows;
    
    // the first time this function is called, it determines what other rows
    // refer to the same project
    // any later calls apply highlighting to those rows if the function is passed true
    // and remove the highlight if false is passed
    doSameProjectRows = function() {
      var sameProjectRows = [],
          sections = section.chart.sections;
      
      // the first time, this function need only determine
      // what assignments have the same project
      sections.forEach(function( section ) {
        section.rows.forEach(function( row ) {
          if( row.assignment.Projects__c === assignment.Projects__c ) {
            sameProjectRows.push(row);
          }
        });
      });
      
      if( sameProjectRows.length > 0 ) {
        // if there are same rows, make a function to highlight/unhighlight
        (doSameProjectRows = function( highlight ) {
          var action = highlight ? "addClass" : "removeClass";
          
          sameProjectRows.forEach(function( row ) {
            row.tr[ action ]("same-project-highlight");
            row.section.resourceRow.tr[ action ]("same-project-highlight");
          });
        
        // highlight the rows now
        })(true);
      } else {
        // no rows, leave this undefined so listeners can ignore it
        doSameProjectRows = undefined;
      }
    };
    
    // references
    this.section = section;
    this.assignment = assignment;
    
    // initially not hidden
    this.hidden = false;
    
    // the bit of text showing the assignment name
    this.assignmentSpan = $("<span />")
      .append(assignment.Name)
      .addClass("de-assignment-span");
    
    // the bit of text showing the project name
    this.projectSpan = $("<span />")
      .append(assignment.Projects__r.Name + " " 
        + (assignment.Client_Rate__c ? 
            " @" + assignment.Client_Rate__c : 
            "(rate unknown)"))
      .addClass("de-gantt-project-span")
      .hover(function() {
        // if there are rows to highlight, highlight them
        doSameProjectRows && doSameProjectRows(true);
      }, function() {
        // if there are rows to unhighlight, unhighlight them
        doSameProjectRows && doSameProjectRows(false);
      });
    
    // <td> containing assignment and project name
    this.nameCell = $("<td />")
      .append(this.assignmentSpan)
      .append("<br />")
      .append(this.projectSpan)
      .addClass("de-gantt-assignment-name");
    
    // appears before assignment bar to show the difference between
    // the project start date and assignment start date
    this.projectPreBar = $("<div />")
      .addClass("de-gantt-project-pre-bar");
    
    // horizontally visualizes the % of available work time used by this assignment
    this.utilizationBar = $("<div />")
      .attr("data-utilization", Math.round(assignment.utilization * 100) + "%")
      .css("position", "absolute")
      .html(Math.round(assignment.utilization * 100) + "%")
      .addClass("de-gantt-utilization-bar");
    
    // visualizes the length of the assignment
    this.assignmentBar = $("<div />")
      .append(this.utilizationBar)
      .addClass("de-gantt-assignment-bar")
      .hover(function() {
        // if there are rows to highlight, highlight them
        doSameProjectRows && doSameProjectRows(true);
      }, function() {
        // if there are rows to unhighlight, unhighlight them
        doSameProjectRows && doSameProjectRows(false);
      })
      
      // on double click, resize the viewing window to just fit this assignment
      .dblclick(function() {
        //var s, e; // save start / end to update controls
        section.chart.setDates(
          assignment.Start_Date__c - DURATION.day,
          assignment.End_Date__c + DURATION.day
        );
      });
    
    // appears after assignment bar to show the difference between
    // the project end date and assignment end date
    this.projectPostBar = $("<div />")
      .addClass("de-gantt-project-post-bar");
    
    // table cell containing the three divs above
    (this.bodyCell = $("<td />")
      .append(this.projectPreBar)
      .append(this.assignmentBar)
      .append(this.projectPostBar)
      .addClass("de-gantt-assignment-body")
    ) // body cell ends here
      .find("> div")
      .css("display", "inline-block");
    
    // table row containing the name and body cells
    this.tr = $("<tr />")
      .append(this.nameCell)
      .append(this.bodyCell)
      .addClass("de-gantt-row de-gantt-assignment");
  };
  
  GanttAssignmentRow.prototype = {
    BELOW_BOUND: -1, // some constants used within .update()
    ABOVE_BOUND: -2,
    
    /**
     * Hides this row, if it isn't already hidden.
     */
    hide: function GanttAssignmentRow_hide() {
      if( this.hidden ) {
        return; // already hidden
      }
      
      this.hidden = true;
      if( this.section.collapsed ) {
        return; // section is collapsed, row is already removed
      }
      
      // just remove the tr
      this.tr.detach();
      
      return this; // for chaining
    },
    
    /**
     * If it is not already visible, shows this row and updates it to ensure it is properly sized.
     */
    show: function GanttAssignmentRow_show() {
      var rows,
          trIndex, index;
      
      if(!this.hidden) {
        return; // already showing
      }
      
      this.hidden = false;
      if(this.section.collapsed) {
        // .show() doesn't matter; section is still hidden
        return;
      }
      
      // this section only executes if the parent section is not collapsed
      // a bit more involved than hide()
      // find the closest NON-HIDDEN row preceding this one
      rows = this.section.rows;
      trIndex = -1; // index of preceding row
      index = 0; // search index
      
      // while we haven't reached this row
      while( rows[index] !== this ) {
        // check the given section
        if( !rows[index].hidden ) {
          // if it's not hidden, then set the used row index to its index
          trIndex = index;
        }
        
        // don't try to confuse anyone, just add one
        index++;
      }
      
      if( trIndex > -1 ) {
        // if an index was found, insert this row after the found one
        rows[trIndex].tr.after(this.tr);
      } else {
        // otherwise, insert it after the resource row
        this.section.resourceRow.tr.after(this.tr);
      }
      
      // update, to be safe
      return this.update();
    },
    
    /**
     * Determines the day offsets for the start and end dates of this row's
     * assignment and its project with respect to the start day specified
     * by the startUTC property of the parent Chart. Offsets out of bounds
     * of the range specified by the parent chart are assignment the value '-1'
     * or '-2'; '-1' is for values below the range, while '-2' is for values above the range.
     * These offsets are used to determine the horizontal positioning and width
     * of the child divs.
     */
    update: function GanttAssignmentRow_update() {
      var // semantic constants
          ABOVE = this.ABOVE_BOUND,
          BELOW = this.BELOW_BOUND,
          TOO_SMALL = 20,
          
          // numbers about current state of chart
          startUTC =     this.section.chart.startUTC,
          endUTC =       this.section.chart.endUTC,
          pixelsPerDay = this.section.chart.pixelsPerDay,
          width =        daysBetween(startUTC, endUTC) * pixelsPerDay,//this.section.chart.width,
          
          // for referencing assignment data
          assignment = this.assignment,
          project =    assignment.Projects__r,
          
          // for calculating day offsets
          offsets = {},
          pastEnd = false,
          
          // for actually sizing bars
          bar, start, end, inner, useBar,
          utilBar = this.utilizationBar;
      
      // calculate the offsets for each relevant date
      [
        ["projectStart", project.Start_Date__c],
        ["assignmentStart", assignment.Start_Date__c],
        ["assignmentEnd", assignment.End_Date__c],
        ["projectEnd", project.End_Date__c]
      ].forEach(function( pair ) {
        var name = pair[0], // offset name
            date = pair[1];  // associated date value
        
        if( pastEnd || ( pastEnd = date > endUTC ) ) {
          // previous date already later than end date, so this one must be too
          // OR, this date is later than end date
          offsets[name] = ABOVE;
        } else if( date < startUTC ) {
          // date occurs before visible start date
          offsets[name] = BELOW;
        } else {
          // otherwise, calculate the number of days between the start date and given date
          offsets[name] = daysBetween(startUTC, date);
        }
      });
      
      // if the assignment isn't visible, just hide the row then quit
      if(offsets.assignmentStart === ABOVE ||
         offsets.assignmentEnd === BELOW) {
        this.hide();
        return;
      } else {
        // otherwise, make sure the row is visible
        this.show();
      }
      
      // a utility function to prepare a bar for sizing
      useBar = function useBar( div, sName, eName ) {
        // force the div to be as small as possible
        bar = div.outerWidth(0);
        
        // get the start and end positions for the div (# of days offset from start)
        start = offsets[sName];
        end = offsets[eName];
        
        // remove any semantic classes from the div
        div.removeClass("no-show no-show-above no-show-below no-start no-end too-small");
        
        if(start === ABOVE) {
          // start is after visible range, note with class
          div.addClass("no-show no-show-above");
        } else if(end === BELOW) {
          // end is before visible range, note with class
          div.addClass("no-show no-show-below");
        } else {
          // group these two ifs together: a div could start before the
          // visible date AND end after the visible date
          
          if(start === BELOW) {
            // start occurs before the view start (but end does not, because that was already checked above)
            // again, note this with a class
            div.addClass("no-start");
          }
          
          if(end === ABOVE) {
            // end occurs after the view end (but start does not, that was already checked above)
            // mark with a class
            div.addClass("no-end");
          }
        }
        
        // convert start to pixels
        start = (start === ABOVE ?
          width :
          start === BELOW ?
            0 :
            start * pixelsPerDay);
        
        // convert end to pixels
        end = (end === ABOVE ?
          width :
          end === BELOW ?
            0 :
            end * pixelsPerDay);
      };
      
      // first, prepare the pre project bar -- indicates time between project start and assignment start
      useBar(this.projectPreBar, "projectStart", "assignmentStart");
      bar.css("margin-left", start);
      if( !bar.hasClass("no-show") ) {
        // if bar is visible
        bar.css("width", end - start);
      }
      
      // now, prepare assignment bar -- indicates assignment duration
      useBar(this.assignmentBar, "assignmentStart", "assignmentEnd");
      if( !bar.hasClass("no-show") ) {
        // if the bar is visible
        bar.css("width", end - start);
        
        // get the inner width to use with the utilization bar
        inner = bar.innerWidth();
        
        if( inner <= TOO_SMALL ) {
          bar.addClass("too-small");
        }
        
        if( bar.hasClass("no-start") ) {
          // add space for arrow
          inner -= 18;
          utilBar.css("left", "18px");
        } else {
          utilBar.css("left", 0);
        }
        
        if( bar.hasClass("no-end") ) {
          // add space for arrow
          inner -= 18;
        }
        
        utilBar.outerWidth((inner * assignment.utilization) + "px");
      }
      
      // finally, prepare post bar -- indicates time between assignment and project end
      useBar(this.projectPostBar, "assignmentEnd", "projectEnd");
      if( !bar.hasClass("no-show") ) {
        // if the bar is visible
        bar.css("width", end - start);
      }
      
      return this; // for chaining
    }
  };
  
  // prepares the gantt chart
  initializeChart = function initializeChart() {
    var ignoreDateChange = false,
        updateChart, formatDate;
    
    //console.log("Got all resources!");
    
    // calculate the hour density (utilization) for each assignment
    assignments.forEach(function( subAssignments ) {
      subAssignments.forEach(function( assignment ) {
        var nh = assignment.Number_Of_Hours__c,
            sd = assignment.Start_Date__c,
            ed = assignment.End_Date__c,
            util = nh / (weekdaysBetween(sd, ed) * 8);
        
        // density (fraction / 1) is number of total hours / total possible hours during assignment period
        assignment.utilization = util;
      });
    });
    
    // all assignments have been gotten, make the chart
    chart = new GanttChart();
    //window.chart = chart; // < debug only
    chartContainer.append(chart.table);
    setTimeout(function() {
      // do this a little later so browsers have time to lay stuff out
      chart.determineDimensions();
      chart.update();
    }, 100);
    
    // function called when datepickers change their dates
    updateChart = function updateChart() {
      var start = $("#start-date").datepicker( "getDate" ).setUTCHours(0, 0, 0, 0),
          end = $("#end-date").datepicker( "getDate" ).setUTCHours(0, 0, 0, 0);
      
      // chart fires a dateChange event here, but it should be ignored to prevent a loop
      ignoreDateChange = true;
      chart.setDates(start, end);
    };
    
    // properly formats chart UTC dates to be passed to .datepicker( "setDate", ... );
    formatDate = function formatDate( date ) {
      return (date.getUTCMonth() + 1) + "/" + date.getUTCDate() + "/" + date.getUTCFullYear();
    };
    
    // whenever the chart's date changes, update the datepickers
    chart.on("dateChange", function( ev ) {
      //console.log("Date change event", ev);
      if( ignoreDateChange ) {
        // if the datepickers caused this dateChange, they will set ignoreDateChange
        // to true -- there's no need to update them when they caused the change
        //console.log("Ignoring event...");
        ignoreDateChange = false;
      } else {
        var sDate = new Date(ev.newStart),
            eDate = new Date(ev.newEnd);
        
        // change the dates on the datepicker controls
        $("#start-date").datepicker( "setDate", formatDate(sDate) );
        $("#end-date").datepicker( "setDate", formatDate(eDate) );
      }
    });
    
    // and, add date range functionality to the chart
    // (borrowed from jqui demo at http://jqueryui.com/datepicker/#date-range)
    $.datepicker.setDefaults({
      dateFormat: "m/d/yy"
    });
    
    // create the start datepicker
    $("#start-date").datepicker({
      changeMonth: true,
      numberOfMonths: 1,
      onClose: function( selectedDate ) {
        $("#end-date").datepicker( "option", "minDate", selectedDate );
        updateChart();
      }
    }).datepicker( "setDate", formatDate(new Date(chart.startUTC)) )
      .change(updateChart);
    
    // create the end datepicker
    $("#end-date").datepicker({
      changeMonth: true,
      numberOfMonths: 1,
      onClose: function( selectedDate ) {
        $("#start-date").datepicker( "option", "maxDate", selectedDate );
        updateChart();
      }
    }).datepicker( "setDate", formatDate(new Date(chart.endUTC)) )
      .change(updateChart);
  };
  
  window.initializeGanttChart = function initializeGanttChart( _resources, _assignments ) {
    // only callable once, so remove the reference to this function
    window.initializeGanttChart = undefined;
    
    // use the given resources and assignments
    resources = _resources; // array of resource info.
    assignments = _assignments; // array of arrays of assignments, in same order as resources
    
    // create the chart
    initializeChart();
  };
});