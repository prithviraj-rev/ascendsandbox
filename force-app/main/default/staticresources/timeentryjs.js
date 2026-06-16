$(function() {
  var $ = jQuery,
      
      CTRL_CLASS = "TomHelloWorld",
      
      container = $("#container"),
      layout,
      
      header = $("#header"),
      
      gridContainer = $("#grid-container"),
      Grid = EditableGrid, 
      grid, makeGrid,
      
      filterContainer = $("#filter-container"),
      
      resource = $("#resource-filter"),
      resources = [],
      currentResource,
      
      week = $("#week-filter"),
      weeks = [],
      currentWeek,
      
      projects = [],
      refresh,
      
      buttonContainer = $("#button-container");
  
  makeGrid = function makeGrid() {
    if(grid) {
      grid.get().remove();
    }
    
    grid = new Grid(projects, weeks[currentWeek].columns, true);
    grid
      .setFooterTitleText("Total")
      .setValidator(function( data ) {
        var error = "";
        
        if((data = data.value).length > 0) {
          if(isNaN(data) || data < 0) {
            error = "Cell value must be a positive number";
          } else if(data.indexOf(".") !== -1 && data.split(".")[1].length > 2) {
            error = "Decimals can only be to the hundredths place";
          } else if(+data > 24) {
            error = "It is impossible to work more than 24 hours in a day!";
          }
        }
        
        return error;
      }).setFooterCallbacks(function( data ) {
        var sum = 0;
        
        data.forEach(function( val ) {
          if(!isNaN(val)) { sum += (+val); }
        });
        
        return "" + Math.round(sum * 100) / 100;
      }).setCornerCallback(function( cellVals, rowFootVals ) {
        return rowFootVals.reduce(function( prev, next ) {
          return prev + +next;
        }, 0);
      });
    gridContainer.append(grid.get());
  };
  
  refresh = function refresh() {
    // TO DO: define /api/projects/<resource-id>/<first-day-of-week>
    // use this api method to get relevant projects
    projects = [
      "First Project",
      "Another Project with a Really Long Name",
      "A Third Project"
    ];
  };
  
  // when the resource is changed, update the currentResource var
  resource.change(function() {
    currentResource = resource.prop("selectedIndex");
    refresh();
    makeGrid();
  });
  
  // get the available resources
  Visualforce.remoting.Manager.invokeAction(
    "{!$RemoteAction." + CTRL_CLASS + ".getResources}",
    function( res, evt ) {
      for(var prop in res) { console.log("result." + prop + " = " + res[prop]); }
      for(var prop in res) { console.log("event." + prop + " = " + res[prop]); }
    }
  );
  /*$.get("/api/resources", {}, function( data ) {
    resources = data;
    
    // create the option drop downs
    resources.forEach(function( rsrc ) {
      resource.append("<option>" + rsrc["first_name"] + " " + rsrc["last_name"] + " (" + rsrc["email"] + ")</option>");
    });
  });*/
  
  // remove the placeholder option (pick one)
  resource.children().eq(0).remove();
  
  // make the chooseable weeks
  (function _determineWeeks() {
    var now = new Date(),
        day = now.getDate(),
        month = now.getMonth(),
        year = 1900 + now.getYear(),
        offset, prevWeek,
        
        monthNames = [
          "January", "February", "March", "April", "May", "June",
          "July", "August", "September", "October", "November", "December"
        ], 
        
        monthLens = [
          31, year % 4 === 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
        ];
    
    // store the options here
    weeks = [];
    
    if((offset = new Date(year, month, 1).getDay()) !== 0) {
      // if the first day of the month is not the first day of its week
      // then find the last Sunday of the previous month
      if(month === 0) {
        // if January, then the first week starts last year
        weeks.push(prevWeek = {
          year: year - 1,
          month: 11,
          day: 31 - (offset - 1) // minus 1 because 31 is already one day before first day of month
        });
      } else {
        weeks.push(prevWeek = {
          year: year,
          month: month - 1,
          day: monthLens[month - 1] - (offset - 1) // again, minus 1 to account for day already moved
        });
      }
    }
    
    console.log("First day of month: " + offset);
    
    // if the month starts on a Sunday, there won't be a previous week
    // so, just make a dummy object
    prevWeek = prevWeek || {};
    
    // iterate while the day is still within the month
    for(day = (7 - offset) + 1; day < monthLens[month]; day += 7) {
      // note the ending date for the previous week
      prevWeek.endYear = year;
      prevWeek.endMonth = month;
      prevWeek.endDay = day - 1;
      
      
      for(var prop in prevWeek) console.log(prevWeek[prop]);
      
      // then push the new one
      weeks.push(prevWeek = {
        year: year,
        month: month,
        day: day
      });
    }
    
    // and note the ending date for the last week
    if((offset = new Date(year, month, monthLens[month]).getDay()) !== 6) {
      // if the last day of the month is not the last day of its week
      // then find the first Saturday of the next month
      if(month === 11) {
        prevWeek.endYear = year + 1;
        prevWeek.endMonth = 0;
        prevWeek.endDay = 6 - offset;
      } else {
        prevWeek.endYear = year;
        prevWeek.endMonth = month + 1;
        prevWeek.endDay = 6 - offset;
      }
    }
    
    // for each week option, make its select option name and column titles
    weeks.forEach(function( obj ) {
      var days = "Sun Mon Tue Wed Thu Fri Sat".split(" "), 
          colNames = [], 
          day;
      
      // select option name
      if(obj.month === obj.endMonth) {
        // if the months are the same, do a shorter title (month day - day, year)
        obj.name = monthNames[obj.month] + " " + obj.day + " - " + obj.endDay + ", " + obj.year;
      } else if(obj.year === obj.endYear) {
        // if the years are the same, do a medium title (month day - month day, year)
        obj.name = monthNames[obj.month] + " " + obj.day + " - " + monthNames[obj.endMonth] + " " + obj.endDay + ", " + obj.year;
      } else {
        // otherwise, longest title (month day, year - month day, year)
        obj.name = monthNames[obj.month] + " " + obj.day + ", " + obj.year + " - " + monthNames[obj.endMonth] + " " + obj.endDay + ", " + obj.endYear;
      }
      
      // column titles
      if(obj.month !== obj.endMonth) {
        // start and end months are different, so start at starting day
        // loop until the end of the month
        for(day = obj.day; day <= monthLens[obj.month]; day++) {
          colNames.push(days.shift() + "<br />" + (obj.month + 1) + " / " + day);
        }
        
        // then pick up the rest in the next month
        for(day = 1; day <= obj.endDay; day++) {
          colNames.push(days.shift() + "<br />" + (obj.endMonth + 1) + " / " + day);
        }
      } else {
        // otherwise, just start at the start day and end at the end day
        for(day = obj.day; day <= obj.endDay; day++) {
          colNames.push(days.shift() + "<br />" + (obj.month + 1) + " / " + day);
        }
      }
      
      obj.columns = colNames;
    });
  }());
  
  // now populate the dropdown
  weeks.forEach(function( weekObj ) {
    week.append("<option>" + weekObj.name + "</option>");
  });
  
  // remove the placeholder option and enable the dropdown
  week
    .attr("disabled", false)
    .change(function() {
      currentWeek = week.prop("selectedIndex");
      refresh();
      makeGrid();
    })
    .children().eq(0)
    .remove();
  
  // the current week / resource is the first one
  currentResource = 0;
  currentWeek = 0;
  
  // once everything's ready, get the projects and make the grid
  refresh();
  makeGrid();
  
  (layout = function layout() {
    // if width < 500, use mobile layout
    if(window.outerWidth < 600) {
      // so long as the layout isn't mobile already
      if(layout.mobile !== true) {
        layout.mobile = true;
        
        [header, filterContainer, gridContainer, buttonContainer].forEach(function( el ) {
          el.detach();
        });
        container.empty();
        
        (function() {
          [header, filterContainer, gridContainer, buttonContainer].forEach(function( el ) {
            container.append($("<tr />").append($("<td />").append(el)));
          });
        }());
      }
    } else {
      if(layout.mobile !== false) {
        layout.mobile = false;
        
        [header, filterContainer, gridContainer, buttonContainer].forEach(function( el ) {
          el.detach();
        });
        container.empty();
        
        (function() {
          var rows;
          
          // otherwise, typical layout: three rows, two columns
          rows = container.append("<tr /><tr /><tr />").find("tr");
          
          // first row is header
          rows.eq(0).append($("<td colspan=2 />").append(header));
          
          // second, third rows first cell is grid
          rows
            .eq(1)
            .append($("<td />").append(filterContainer))
            .append($("<td rowspan=2/>").append(buttonContainer));
         
           // second, third rows seconds cells are filters, buttons
          rows.eq(2).append($("<td style='vertical-align:top'/>").append(gridContainer));
        }());
      }
    }
    
    // all extra space should go to the grid, so size all other heights to their actual values
    [header, filterContainer/*, buttonContainer*/].forEach(function( el ) {
      var e = $(el);
      
      e.parent().outerHeight(e.outerHeight());
    });
  })();
  
  window.onresize = layout;
});