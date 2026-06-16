var OmniGrid = (function _initOmniGrid() {
  var // jquery alias
      $ = window.$,
      DataObject,
      EventManager,
      
      // a function to get class names
      CSS,
      
      // utility
      slice = [].slice,
      strip,
      fill,
      proxy,
      isArray = Array.isArray,
      
      // common use
      /**
       * Describes valid names for cell types.
       * @type RegExp
       */
      TYPE_NAME = /^[a-zA-Z0-9_:-]+$/,
      
      // managers
      Cells,
      Rows,
      Column,
      Grids,
      
      // grid
      OmniGrid;
  
  // if no jQuery, fail; if already defined, don't redefine
  if(!$) {
    console.log("Failed to initialize OmniGrid; jQuery was not found");
    return;
  } else if(window.OmniGrid) {
    console.log("Didn't initialize OmniGrid; it was already initialized by a previous script");
    return;
  }
  
  // data-managing
  DataObject = function DataObject() {
    // create the data-storing hash
    this._data = {};
  };
  
  DataObject.prototype = {
    getData: function DataObject_getData( prop/*, prop2, ..., propN */ ) {
      var ret, i,
          data = this._data;
      
      if(arguments.length === 1) {
        // just one prop, so get the value
        ret = data[prop];
      } else {
        // multiple props, return them in a hash
        ret = {};
        for(i = 0; i < arguments.length; i++) {
          prop = arguments[i];
          ret[prop] = data[prop];
        }
      }
      
      return ret;
    },
    
    setData: function DataObject_setData( prop, val ) {
      var obj,
          data = this._data;
      
      if(typeof prop === "string") {
        // just a prop-val pair, set the val
        data[prop] = val;
      } else {
        // hash of prop-val pairs, set them all
        obj = prop;
        for(prop in obj) {
          data[prop] = obj[prop];
        }
      }
      
      return this;
    },
    
    hasData: function DataObject_hasData( prop ) {
      return prop in this._data;
    },
    
    clearData: function DataObject_clearData() {
      var i, data;
      
      if(arguments.length === 0) {
        // no args, so clear data (must be done via 'this' reference)
        this._data = {};
      } else {
        // args, so just remove those props
        data = this._data;
        for(i = 0; i < arguments.length; i++) {
          delete data[arguments[i]];
        }
      }
    }
  };
  
  // event-managing object
  EventManager = function EventManager( thisArg ) {
    this._callbacks = {};
    this.context = thisArg;
  };
  
  EventManager.prototype = {
    allowedNames: /[A-Za-z]+/,
    
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
          if( cbArray && (index = cbArray.indexOf(callback), index !== -1) ) {
            cbArray.splice(index, 1);
          }
        } :
        
        // no callback, remove all listeners
        function( type ) {
          callbacks[type] = [];
        });
      } else {
        // remove all occurrences of the given callback
        for( type in callbacks ) {
          cbArray = callbacks[type];
          if( index = cbArray.indexOf(callback), index !== -1 ) {
            cbArray.splice(index, 1);
          }
        }
      }
      
      return this;
    },
    
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
      
      return this;
    }
  };
  
  // create the function to get CSS class names
  /**
   * Returns the CSS class associated with the given component.
   * 
   * @param {String} part  The name of the component
   * 
   * @returns {String}     The CSS class associated with that component
   */
  CSS = (function _initCSS( prefix, hash ) {
    for(var prop in hash) {
      hash[prop] = prefix + "-" + hash[prop];
    }
    
    return function( part ) {
      if(part in hash) {
        return hash[part];
      } else {
        throw new Error("OmniGrid: No such component class '" + part + "'");
      }
    };
  }("og", {
    "Cell":      "cell",
    "RowHeader": "rowheader",
    "RowFooter": "rowfooter",
    "ColHeader": "colheader",
    "ColFooter": "colfooter",
    "Row":       "row",
    "HeaderRow": "headerrow",
    "FooterRow": "footerrow",
    "Grid":      "grid"
  }));
  
  /**
   * Returns a new Array containing each value present in the original array at most once, in the order the
   * values are encountered in the array. For example, the call [1, 3, 6, 2, 3, 1].asSet() would return the
   * array [1, 3, 6, 2].
   * 
   * @returns {Array}  An array containing values found in the original array at most once
   */
  Array.prototype.asSet = function() {
    var set = [];
    this.forEach(function(v) {
      if(set.indexOf(v) === -1) {
        set.push(v);
      }
    });
    return set;
  };
  
  $.fn.insert = function( index, element ) {
    var length = this.children().length;
    
    if( index < 0 ) {
      index = Math.max(0, length + index);
    }
    
    if( index === 0 ) {
      this.prepend(element);
    } else if( index >= length ) {
      this.append(element);
    } else {
      this.children().eq(index).before(element);
    }
    
    return this;
  };
  
  /**
   * Deletes each property on the given object obj whose name does not appear in the given list of property
   * names.
   * 
   * @param {Object} obj    The object to strip
   * @param {Array}  props  The properties to retain
   * 
   * @returns {Object}      The given object, stripped of all unnecessary properties
   */
  strip = function strip( obj, props ) {
    var index;
    props = props.slice(0);
    for(var prop in obj) {
      if((index = props.indexOf(prop)) !== -1) {
        // if the property should be retained, then remove its name from props
        props.splice(index, 1);
      } else {
        // otherwise, delete the property
        delete obj[prop];
      }
    }
    
    return obj;
  };
  
  /**
   * For each key-value pair found in the object defs, this function fills the value into the object obj if
   * obj does not already possess a value for the given key.
   * 
   * @param {object} obj   The object whose properties should be filled
   * @param {object} defs  The key-value pairs to fill into obj
   * 
   * @returns {object}  The mutated object obj
   */
  fill = function fill( obj, defs ) {
    for(var prop in defs) {
      if(!(prop in obj)) {
        obj[prop] = defs[prop];
      }
    }
    
    return obj;
  };
  
  /**
   * Searches the given object for any member functions, and returns a new object containing copies of those
   * functions bound to the original object. This function is used by Cells, Rows, Columns, and Groups to
   * protect their sensitive fields (while still enabling those fields to be public within this closure).
   * 
   * @param {Object} obj        The object to proxy
   * @param {Object} [options]  A hash indicating functions to omit and / or fields to copy:
   *   "include"  String[]  Names of fields to copy, if they exist (by default, no fields are copied)
   *   "exclude"  String[]  Names of functions NOT to copy (by default, all functions are copied)
   * 
   * @returns {Object}  A proxy to the given object, containing any methods found on the original object
   */
  proxy = function proxy( obj, options ) {
    var proxy = {}, 
        prop, val, index,
        exclude, include, map;
    
    options = options || {};
    
    // make sure include and exclude are array
    isArray(include = options.include) || (include = []);
    isArray(exclude = options.exclude) || (exclude = []);
    (map = options.map) instanceof Array || (map = {});
    
    for( prop in obj ) {
      val = obj[prop];
      if( typeof val === "function" ) {
        if( index = exclude.indexOf(prop), index === -1 ) {
          // function isn't excluded, add it to proxy
          // map to a new name if requested
          proxy[prop in map ? map[prop] : prop] = (function( method ) {
            return function() {
              var ret = method.apply(obj, arguments);
              // preserve the useful chaining nature of certain methods, but be careful:
              // can't return the actual object (defeats the purpose of the proxy),
              // so for any functions returning 'this', return the proxy instead
              return ret === obj ? proxy : ret;
            };
          }(val));
        } else {
          // function is excluded, remove name from list
          exclude.splice(index, 1);
        }
      } else if( prop in map ) {
        // if the prop should be mapped, do so
        proxy[map[prop]] = obj[prop];
      } else if( index = include.indexOf(prop), index !== -1 ) {
        // otherwise, if the property should be included, add it and remove name from list
        proxy[prop] = val;
        include.splice(index, 1);
      }
    }
    
    return proxy;
  };
  
  // create the cell managing object
  Cells = (function _initCells() {
    var /**
         * A wrapper object responsible for the management of CellTypes and the creation of Cells.
         * @type Object
         */
        Cells = {},
        
        // CellType stuff
        CellType,
        
        /**
         * A hash of the default property values for CellTypes.
         * @type Object
         */
        CELL_TYPE_DEFAULTS = {
          header: false,
          init: function() {},
          cache: true,
          initialValue: undefined,
          getValue: function() {
            return this.text();
          },
          setValue: function( val ) {
            val = "" + val;
            this.html(val);
            return val;
          }
        },
        
        /**
         * A list of the property names that can be used to configure a Cell.
         * @type Array
         */
        CELL_CONFIG_PROPS = Object.keys(CELL_TYPE_DEFAULTS),
        
        /**
         * A hash mapping valid type names to CellType objects responsible for the creation of cells of the
         * corresponding type.
         * @type Object.<string, CellType>
         */
        types = {},
        
        // Cell constructor
        Cell;
    
    /**
     * Creates a new CellType object.
     * 
     * @param {object} config
     *   A hash of properties defining the behavior of Cells of this type. The values stored here essentially
     *   act as defaults when creating Cells of this type; when Cell construction actually occurs, values may
     *   be provided to override these defaults.
     *   
     *   header    boolean   true if this Cell should be a th element, false if it should be a td. If not
     *                       specified, this value defaults to false.
     *   init      function  Called when a Cell is initially created. Within this function, 'this' references
     *                       the newly created Cell. If not specified, an empty function is used instead.
     *                       This function will be passed two arguments when called to construct a cell:
     *                       params  (Object)
     *                           A hash of properties passed from the Cell creator, used to guide the creation
     *                           of the specific Cell being created.
     *                       fireUpdate  Function( [old, new][, data] )
     *                           A function that should be called whenever the Cell's value updates. It is
     *                           CRUCIAL this function be called IMMEDIATELY after the value that would be
     *                           returned by the Cell's .getValue() method changes, as the Grid utilizes a
     *                           value caching mechanism behind the scenes to provide greater performance.
     *                           NOTE: If the value of a CellType is prone to common changes or the retrieval
     *                           of its value is a trivial process, then the configuration option "cache" can
     *                           be set to "false" to hint to the Grid to always call .getValue() when
     *                           internally determining the value of a Cell. BUT USE CAUTION: For any Cell
     *                           whose configuation option "cache" is set to false, fireUpdate() MUST be
     *                           passed the old and new values as its first two arguments. When caching is
     *                           active, these values can be inferred (and in fact passing them is forbidden),
     *                           but it is impossible to know the previous value if it is not cached, so non-
     *                           caching Cells must provide these values when they fire updates.
     *                           This function can be passed a hash of key-value pairs to be exposed as event
     *                           data to update listeners for this Cell. If omitted, an empty object {} is
     *                           used instead.
     *                             
     *   cache     boolean   Indicates whether or not the Grid should cache the values of Cells of this type.
     *                       If true (which is the default value), then the Grid will save the value held in
     *                       Cells of this type to return and use in Grid methods. The cached value will be
     *                       updated ONLY in these two situations:
     *                         1. The .setValue() method is invoked upon the Cell object (which can only occur
     *                            through internal Grid behavior) or upon the Cell's element.
     *                         2. The callback passed as the second argument to the Cell's .init() function
     *                            is invoked.
     *   initialValue        The initial value to cache for a Cell of this type, if that Cell opts into value
     *             anything  caching (which can be disabled on an individual Cell basis through the config
     *                       hash passed to a Cell upon its creation). If left undefined (as is done defaultly),
     *                       then the Cell's .getValue() method will be called to determine the initial value
     *                       once all other initialization has finished. 
     *   getValue  function  Important required functionality within the grid. This method is used to report
     *                       a Cell's value to other Cells during update events or any other times at which 
     *                       the Cell's value is requested. Within this function, 'this' refers to the jQuery 
     *                       element that represents the Cell. If not specified, this function returns the
     *                       value returned by the jQuery method .text() on the Cell.
     *   setValue  function  Important required functionality within the grid. This method is used indirectly
     *                       to set a Cell's value, and is always passed a single parameter representing the
     *                       value to set. This value can be anything; strings, arrays, objects, etc. are all 
     *                       allowed; the creator of the Cell type has control over the value-setting scheme. 
     *                     ! IMPORTANT: The Grid does not inherently know whether or not a value passed to
     *                       .setValue() is valid for the Cell to which it is being passed; therefore,
     *                       .setValue() MUST throw an error if an invalid value is encountered. That way, the
     *                       Grid is made aware the value-setting was unsuccessful and does not fire events.
     *                     ! ALSO IMPORTANT: When some process in a Grid calls .setValue() on a Cell, the
     *                       function given in this configuration hash for setValue() MUST return the value
     *                       resolved from the given input. For example, if the value of a dropdown Cell is
     *                       the current item's text, but the setValue function allows indices to be used to
     *                       set the new value, then setValue must return the text of the newly selected item
     *                       (determined from the passed index). For Cells that cache their values, this return
     *                       value is cached, and regardless of caching the returned value is used in events.
     *                       Within this function, 'this' refers to the Cell. If not specified, this function 
     *                       sets the contents of the Cell as determined by the jQuery method 
     *                       .html( newContent ).
     * 
     * @constructor
     */
    CellType = function CellType( config ) {
      // fill the computed values into this CellType object
      fill(this, fill(config, CELL_TYPE_DEFAULTS));
    };
    
    /**
     * Creates a new Cell with the properties and behaviors described by the given config object.
     * 
     * @param {Row}     row     A reference to this Cell's parent Row
     * @param {Column}  column  A reference to the Column object "containing" this Cell
     * @param {Object}  config  A hash of properties used to initialize the new Cell
     *   (Any of the CellType configuration options can be overridden here. For details on those options, see
     *   the documentation for CellType).
     *   type    String  Internal only. The name of the Cell's type.
     *   params  Object  A hash of properties passed to this Cell's CellType's .init() function to provide 
     *                   further customization of Cell initialization. The values in this hash are passed
     *                   by the creator of the Cell.
     *   
     * @constructor
     */
    Cell = function Cell( row, column, config ) {
      var initFireUpdate,
          fireUpdate,              // for initiating update events
          value;                   // for caching the value, if requested
      
      /**
       * The name of the type used to create this Cell, or undefined if an anonymous type was used.
       * @type String
       */
      this.type = config.type;
      
      /**
       * A reference to the Row containing this Cell.
       * @type _initOmniGrid._initRows.Row
       */
      this.row = row;
      
      /**
       * A reference to the Column containing this Cell.
       * @type _initOmniGrid.Column
       */
      this.column = column;
      
      /**
       * The table cell element representing this Cell.
       * @type jQuery
       */
      this.element = $(config.header ? "<th />" : "<td />")
        .addClass(CSS("Cell"))
        .attr("data-og-type", this.type);
      
      // data properties (but overwrite getData() to check parents too)
      fill(this, new DataObject());
      this.getData = (function( cellHasData, getCellData ) {
        var dataObjs = [
              { 
                hasData: cellHasData,
                getData: getCellData
              }, 
              row, 
              column, 
              row.grid
            ],
            get;
        
        get = function( prop ) {
          var i, 
              found = false,
              value = undefined;
          
          for(i = 0; !found && i < dataObjs.length; i++) {
            if(dataObjs[i].hasData(prop)) {
              found = true;
              value = dataObjs[i].getData(prop);
            }
          }
          
          return value;
        };
        
        return function Cell_getData( prop ) {
          if(arguments.length > 1) {
            return slice.call(arguments).reduce(function( prev, curr ) {
              prev[curr] = get(curr);
              return prev;
            }, {});
          } else {
            return get(prop);
          }
        };
      }(this.hasData.bind(this), this.getData.bind(this)));
      
      // to hold listeners and manage events
      fill(this, new EventManager(function() {
        return this.getProxy();
      }.bind(this)));
      
      // fireUpdate call listeners, then propagate upward
      fireUpdate = function( evt ) {
        // add this as source
        evt.source = this.getProxy();
        
        // call the listeners
        this.fire("update", evt);
        row.fire("update", evt);
        column.fire("update", evt);
        row.grid.fire("update", evt);
      }.bind(this);
      
      // getValue and initUpdateFn
      if(config.cache) {
        // if value caching is active for this Cell, then use special .getValue() and method
        this.getValue = function Cell_getValue() {
          return value;
        };
        
        // the initializer's update callback can infer the old and new values in this case
        initFireUpdate = (function Cell__controls_fireUpdate( updateData ) {
          var oldValue;
            
          if(arguments.length > 1) {
            // throw an error here, because this lack of consistency is confusing
            // by throwing an error, the user's misunderstanding of this behavior can be fixed
            throw new Error("Expected zero or one argument when calling fireUpdate() during Cell "
              + "initialization, but instead got " + arguments.length + ".\n"
              + "\tWhen value caching is active, the old and new Cell values can be determined and do not need "
              + "to be passed to the fireUpdate() callback withing the initialization function.");
          } else {
            oldValue = value;
            value = config.getValue.call(this.element);
            fireUpdate({
              oldValue: oldValue,
              newValue: value,
              auto: false,
              data: arguments.length === 0 ? {} : updateData
            });
          }
        }).bind(this);
      } else {
        // otherwise, always invoke the specified procedure to get values
        this.getValue = config.getValue.bind(this.element);
        
        // without caching, the initializer's update callback cannot infer old and new values
        // so they must be passed
        initFireUpdate = (function Cell__controls_fireUpdate( oldValue, newValue, updateData ) {
          if(arguments.length < 2 || arguments.length > 3) {
            // throw an error here, because this lack of consistency is confusing
            // by throwing an error, the user's misunderstanding of this behavior can be fixed
            throw new Error("Expected two or three arguments when calling fireUpdate() during Cell "
              + "initialization, but instead got " + arguments.length + ".\n"
              + "When value caching is turned off, Cells cannot determine the old and new value to associate "
              + "with an update event, so you must manually pass them. If this is undesirable or impossible, "
              + "change the definition of CellType '" + this.type + "' to use caching, or override the "
              + "behavior on only this Cell by passing a configuration hash when it is defined.");
          } else {
            fireUpdate({
              oldValue: oldValue,
              newValue: newValue,
              auto: false,
              data: arguments.length === 2 ? {} : updateData
            });
          }
        }).bind(this);
      }
      
      /**
       * Forces the updating of this Cell's value to the given one (or to some value interpreted from the
       * given one), optionally associating update data with the eventual event that will be fired.
       * 
       * @param {*}       newValue    The value to set in the Cell
       * @param {Object}  updateData  Data to associate with the update event
       * 
       * @returns {undefined}  Nothing.
       */
      this.setValue = function Cell_setValue( newValue, updateData ) {
        var oldValue = this.getValue();
        // try to set the new value, trusting that the user-defined .setValue()
        // will throw an exception if the value is invalid
        try {
          // the user-defined .setValue() should return the interpreted value
          value = config.setValue.call(this.element, newValue);
          if(value === undefined) {
            value = newValue;
          }
          fireUpdate({
            oldValue: oldValue,
            newValue: newValue,
            auto: true,
            data: arguments.length === 2 ? {} : updateData
          });
        } catch(e) {
          console.warn("Failed to update the value of a Cell of type '" + this.type + "': " + e.message);
        }
      };
      
      // initialize the cell as requested, refer to the table cell element as 'this'
      // in addition to the special controls (fireUpdate and onUpdate), fill in proxy methods so the Cell can
      // take advantage of them
      config.init.call(this.getProxy(), config.params, initFireUpdate);
      
      // if value caching is active, get the initial value of the Cell
      config.cache && (value = 
        config.initialValue === undefined ? 
          config.getValue.call(this.element) : 
          config.initialValue
        );
    };
    
    Cell.prototype = {
      getRowIndex: function Cell_getRowIndex() {
        return this.row.index;
      },
      
      getRowName: function Cell_getRowName() {
        return this.row.name;
      },
      
      getColumnIndex: function Cell_getColumnIndex() {
        return this.column.index;
      },
      
      getColumnName: function Cell_getColumnName() {
        return this.column.name;
      },
      
      getRow: function Cell_getRow() {
        return this.row.getProxy();
      },
      
      getColumn: function Cell_getColumn() {
        return this.column.getProxy();
      },
      
      getGrid: function Cell_getGrid() {
        return this.row.grid.getProxy();
      },
      
      // get/set value
      // get/set data
      // on/off/fire listeners / events
      
      // no need to have getter for element; it's included in proxy
      
      getProxy: function Cell_getProxy() {
        return proxy(this, {
          include: [ "type", "element" ]
        });
      }
    };
    
    /**
     * Defines a new CellType, optionally associating static data with the type.
     * 
     * @param {String} name      The name of the CellType to create
     * @param {Object} config    A hash of configuration controls for the CellType
     * @param {Object} [static]  An optional hash of static data to associated with the new type
     * 
     * @returns {Cells}  The Cells object, for chaining
     */
    Cells.defineType = function Cells_defineType( name, config ) {
      // make sure name is valid and not taken
      if(!TYPE_NAME.test(name)) {
        throw new Error("Cell type name '" + name + "' is invalid (names can only contain letters, numbers, underscores, dashes, and colons)");
      } else if(name in types) {
        throw new Error("Cell type '" + name + "' already exists");
      }
      
      // create the type, using properties given in config (but stripped of unnecessary properties)
      types[name] = new CellType(strip(config, CELL_CONFIG_PROPS));
      return Cells;
    };
    
    /**
     * Creates a new Cell.
     * 
     * @param {String}  typeName  The name of the CellType for the new Cell
     * @param {Row}     row       A reference to this Row's parent Cell
     * @param {Column}  column    A reference to the Column containing this Cell
     * @param {Object}  params    Configuration options to pass to the Cell's initializer
     * @param {Object}  config    Hash of optional behaviors to override those specified by the requested type
     * 
     * @returns {Cell}  A new Cell
     */
    Cells.create = function Cells_create( typeName, row, column, params, config ) {
      if(typeName !== undefined) {
        // if type name given, make sure name is valid and CellType exists
        if(!TYPE_NAME.test(typeName)) {
          throw new Error("Cell type name '" + typeName + "' is invalid (names can only contain letters, numbers, underscores, dashes, and colons)");
        } else if(!(typeName in types)) {
          throw new Error("Cell type '" + typeName + "' does not exist");
        }
        
        // fill in type defaults to config
        fill(strip(config, CELL_CONFIG_PROPS), types[typeName]);
      }
      
      // note the type, reference the params
      config.type = typeName;
      config.params = params;
      
      return new Cell(row, column, config);
    };
    
    return Cells;
  }());
  
  // create the Row managing object
  Rows = (function _initRows() {
    var /**
         * A wrapper responsible for managing RowTypes and creating Rows.
         * @type Object
         */
        Rows = {},
        
        // RowType stuff
        RowType,
        
        /**
         * A hash of the default property values for RowTypes.
         * @type Object
         */
        ROW_TYPE_DEFAULTS = {
          init: function() {}
        },
        
        /**
         * A list of the property names that can be used to configure a Row.
         * @type Array
         */
        ROW_CONFIG_PROPS = Object.keys(ROW_TYPE_DEFAULTS),
        
        types = {},
        
        // Row constructor
        Row;
    
    /**
     * Creates a new RowType object.
     * 
     * @param {Object} config
     *   A hash of properties defining the behavior of Rows of this type. The values stored here essentially
     *   act as defaults when creating Rows of this type; when Row construction actually occurs, values may
     *   be provided to override these defaults.
     *   
     *   init  Function  Called to initialize the custom behavior of functionality associated with Rows of
     *                   this RowType. Within the function 'this' can be used to reference the jQuery object
     *                   associated with the new Row (this object IS the tr element which will eventually be
     *                   displayed in the Grid, so any jQuery manipulation is acceptable). NOTE that with this
     *                   power comes responsibility: though child Cells are not actually added to the Row
     *                   until after the .init() function finishes, callbacks may be registered to remove the
     *                   Row's children or perform other malicious actions which will disrupt the performance
     *                   of the Grid. As such, jQuery methods involving manipulation of parent or child
     *                   elements SHOULD BE AVOIDED. If no function is specified here, an empty one is used
     *                   instead.
     *                   The init function will be passed two arguments:
     *                   params  (Object)
     *                       A hash with key-value pairs used to further customize initialization of this Row.
     *                       This hash is passed when a new Row is created (which can only occur within the
     *                       .init() function for a Group). An example key-value pair might be a property
     *                       called "disabled" whose value is either true or false; to create an initially
     *                       disabled Row, the params object will contain the pair "disabled": true. Of course,
     *                       just declaring that pair in the params object will not actually disable the Row;
     *                       the .init() function for that Row's type must check the params object for the
     *                       disabled property and act accordingly.
     *                   controls  (Object)
     *                       A hash containing various methods providing access to and manipulation of the
     *                       Row:
     *                     addCell  (Function)
     *                       Used to add new Cells to the Row.
     *                       This function can be used in a variety of ways:
     *                         addCell( String type [ , Object params [ , Object config ] ] )
     *                           Creates a new Cell of the specified CellType (if such a type exists).
     *                           If given, the params are passed to the .init() function for the Cell.
     *                           If given, the denoted configuration options are used to override those
     *                           defaultly provided by the requested type.
     *                         addCell( Object config )
     *                           Creates a new Cell using the given configuration controls.
     *                     onUpdate  (Function)
     *                       Call this to register a listener used to respond to changes in Cells' values. Any
     *                       listener registered here will be called before this Row's parent Group is
     *                       notified of the change. To register a listener, simply pass a function to the 
     *                       given onUpdate argument of the .init() function.
     *                       The passed callback will receive a single argument encapsulating the details of
     *                       the update. It will contain the following properties:
     *                         index     Number      The zero-based index of the updated Cell in this Row
     *                         oldValue  anything    The value previously contained in the Cell
     *                         newValue  anything    The new value represented by the Cell
     *                         auto      Boolean     true if this update was automatically triggered by the
     *                                               Grid's use of a Cell's .setValue() method
     *                         data      Object      Extra information passed by the updating Cell
     *                         values    anything[]  An array containing the values of all Cells in the Row
     *                                               in order
     *                         set       Function    Used to update Cells' values. Requires two arguments:
     *                                                 index  Number
     *                                                   The index of the Cell whose value should be set
     *                                                 newValue  anything
     *                                                   The new value to pass to the Cell's .setValue() method
     *                     getWidth  (Function)
     *                       Returns the current number of columns present in the Row.
     *                     getIndex  (Function)
     *                       Returns the index of this Row within its parent Group
     *                     parent    (proxy to parent Group)
     *                       A partial representation of this Row's parent Group.
     *                     element   (jQuery)
     *                       The jQuery object representing this Row's tr element
     *                     getCell   (Function)
     *                       Returns the Cell at the specified column index, if it exists.
     * 
     * @constructor
     */
    RowType = function RowType( config ) {
      // fill the computed values into this RowType object
      fill(this, fill(config, ROW_TYPE_DEFAULTS));
    };
    
    /**
     * Creates a new Row with the properties and behaviors described by the given config object.
     * 
     * @param {Grid}    grid    A reference to the Row's parent Grid
     * @param {String}  name    The Row's name
     * @param {Object}  config  A hash of properties used to initialize the new Row
     *   (Any of the RowType configuration options can be overridden here. For details on those options, see
     *   the documentation for RowType).
     *   type    String  Internal only. The name of the Row's type.
     *   params  Object  A hash of properties passed to this Row's RowType's .init() function to provide 
     *                   further customization of Row initialization. The values in this hash are passed
     *                   by the creator of the Row.
     * 
     * @constructor
     */
    Row = function Row( grid, name, config ) {
      var initAddCell;
      
      /**
       * The name of the type used to create this Row (or undefined if no type was used).
       * @type String
       */
      this.type = config.type;
      
      /**
       * This Row's index within its parent Grid.
       * @type Number
       */
      this.index = grid.rows.length;
      
      /**
       * This Row's name within its parent Grid.
       * @type String
       */
      this.name = name;
      
      /**
       * This Row's parent Grid.
       * @type _initOmniGrid._initGrids.Grid
       */
      this.grid = grid;
      
      /**
       * The jQuery representation of this row (as 'tr' element).
       * @type jQuery
       */
      this.element = $("<tr />")
        .addClass(CSS("Row"))
        .attr("data-og-type", this.type);
      
      // header and footer
      this.header = $("<th />")
        .attr("scope", "row")
        .addClass(CSS("RowHeader"));
      this.footer = $("<td />")
        .addClass(CSS("RowFooter"));
      
      /**
       * A list of this Row's Cells, in the order they are displayed.
       * @type _initOmniGrid._initCells.Cell[]
       */
      this.cells = [];
      
      // add data functionality to the Row
      fill(this, new DataObject());
      
      // add event listener functionality
      fill(this, new EventManager(function() {
        return this.getProxy();
      }.bind(this)));
      
      // prepare the callbacks to pass to the init function
      // since the addCell function is actually publicly visible, input validation must occur
      initAddCell = (function Row__init_addCell( type, params, config ) {
        var cells = this.cells;
        
        // make sure the initializer isn't adding too many Cells
        if(cells.length === this.grid.width) {
          // only have to check ===, the list will never be allowed to get longer
          throw new Errow("Cannot add another Cell to new Row; it already has enough Cells.");
        }
        
        // begin input validation
        if(arguments.length === 1) {
          // argument should be a string (type name) or an object
          if(typeof type === "string" || type instanceof String) {
            // if it's a string, treat it as a type name
            params = {};
            config = {};
          } else if(type instanceof Object) {
            // if it's an object, treat it as a configuration hash
            config = type;
            type = undefined;
            params = {};
          } else {
            throw new Error("Single argument passed to addCell within Row initializer must be a string "
                    + "indicating the type to use or an object containing configuration information; instead, "
                    + "'" + type + "' was passed.");
          }
        } else if(arguments.length === 2) {
          if(!(typeof type === "string" || type instanceof String)) {
            // type must be a string
            throw new Error("First argument of two passed to addCell within Row initializer must be a string "
                    + "indicating the type to use.");
          } else if(!(params instanceof Object)) {
            // params must be an object
            throw new Error("Second argument of two passed to addCell within Row initializer must be an object "
                    + "containing initialization parameters to pass to the new Cell.");
          }
          
          // everything okay, config is empty
          config = {};
        } else if(arguments.length === 3) {
          if(!(typeof type === "string" || type instanceof String)) {
            // type must be a string
            throw new Error("First argument of three passed to addCell within Row initializer must be a string "
                    + "indicating the type to use.");
          } else if(!(params instanceof Object)) {
            // params must be an object
            throw new Error("Second argument of three passed to addCell within Row initializer must be an object "
                    + "containing initialization parameters to pass to the new Cell.");
          } else if(!(config instanceof Object)) {
            // config must be an object
            throw new Error("Third argument of three passed to addCell within Row initializer must be an object "
                    + "containing configuration parameters to use when creating the new Cell.");
          }
          
          // everything okay
        } else {
          // invalid number of arguments, complain
          throw new Error("Function addCell within Row initializer expects one to three arguments, "
                  + "but " + arguments.length + " were given.");
        }
        
        // if no error by now, everything's alright and arguments will have correct values
        var cell = Cells.create(type, this, this.grid.columns[cells.length], params, config);
        cells.push(cell);
        return cell.getProxy();
      }).bind(this);
      
      // initialize the Row as requested
      config.init.call(this.getProxy(), config.params, initAddCell);
      
      // if not the correct number of Cells, complain
      if( this.cells.length !== this.grid.columns.length ) {
        throw new Error("Initializer for Row did not add enough Cells; expected " + this.grid.width + " but got " + this.cells.length);
      }
      
      // add all the Cells' elements to this Row's element
      if( grid.rowHeaders ) {
        this.element.append(this.header);
      }
      (function( cells, el ) {
        cells.forEach(function( cell ) {
          el.append(cell.element);
        });
      }(this.cells, this.element));
      if( grid.rowFooters ) {
        this.element.append(this.footer);
      }
    };
    
    Row.prototype = {
      getWidth: function Row_getWidth() {
        return this.grid.columns.length;
      },
      
      getGrid: function Row_getGrid() {
        return this.grid.getProxy();
      },
      
      getCell: function Row_getCell( name ) {
        var index;
        if( typeof name === "number" ) {
          index = name;
          if( index % 1 !== 0 || index < 0 || index >= this.cells.length ) {
            throw new Error(index + " is not a valid Cell index");
          }
        } else {
          index = this.grid.columnNames.indexOf("" + name);
          if(index === -1) {
            throw new Error("There is no column with the name '" + name + "'");
          }
        }
        
        return this.cells[index].getProxy();
      },
      
      getCells: function Row_getCells( criteria ) {
        var cells,
            c, min, max;
        
        criteria instanceof Object || (criteria = {});
        
        // filter by indices
        min = +criteria.min || undefined;
        max = +criteria.max || undefined;
        cells = this.cells.slice(min, max);
        
        // filter by column names
        if("columns" in criteria) {
          c = criteria.columns;
          if(typeof c === "string" || c instanceof String) {
            // it type is a string, make it an array
            c = [c];
          }
          
          if(c instanceof Array) {
            // if an Array, find all indices corresponding to the given names, then sort and map to those indices
            cells = c.asSet().reduce(function( prev, curr ) {
              var index = this.grid.columnNames.indexOf(name);
              if(index !== -1 && prev.indexOf(index) === -1) {
                prev.push(index);
              }
              return prev;
            }, []).map(function( index ) {
              return cells[index];
            });
          }
        }
        
        // filter by Cell type
        if("type" in criteria) {
          c = criteria.type;
          if(typeof c === "string" || c instanceof String) {
            // it type is a string, make it an array
            c = [c];
          }
          
          if(c instanceof Array) {
            // if an array, filter out all Cell's whose type does not appear in the list
            cells = cells.filter(function( cell ) {
              return c.indexOf(cell.type) !== -1;
            });
          }
        }
        
        return cells.map(function( cell ) {
          return cell.getProxy();
        });
      },
      
      forEachCell: function Row_forEachCell( callback ) {
        if( typeof callback !== "function" ) {
          return;
        }
        
        this.cells.forEach(function( cell ) {
          callback.call(cell.getProxy());
        });
      },
      
      getValues: function Row_getValues( asHash ) {
        var ret;
        
        if(asHash) {
          ret = {};
          this.cells.forEach(function( cell ) {
            ret[cell.getColumnName()] = cell.getValue();
          });
        } else {
          ret = this.cells.map(function( cell ) {
            return cell.getValue();
          });
        }
        
        return ret;
      },
      
      getElements: function Row_getElements( doHeader, doFooter ) {
        var collection = $([]);
        
        if( arguments.length === 1 ) {
          doHeader = doFooter = !!doHeader;
        } else {
          doHeader = !!doHeader;
          doFooter = !!doFooter;
        }
        
        if( doHeader ) {
          collection = collection.add(this.header);
        }
        
        collection = this.cells.reduce(function( collection, cell ) {
          return collection.add(cell.element);
        }, collection);
        
        return doFooter ? collection.add(this.footer) : collection;
      },
      
      doHeader: function Row_doHeader( show ) {
        if( show ) {
          this.element.prepend(this.header);
        } else {
          this.header.detach();
        }
      },
      
      doFooter: function Row_doFooter( show ) {
        if( show ) {
          this.element.append(this.footer);
        } else {
          this.footer.detach();
        }
      },
      
      // get/set data
      // on/off/fire listener/event
      
      getProxy: function Row_getProxy() {
        return proxy(this, {
          include: [ "type", "index", "name", "element", "header", "footer" ],
          exclude: [ "doHeader", "doFooter" ]
        });
      }
    };
    
    /**
     * Defines a new RowType.
     * 
     * @param {String} name    The name of the RowType to create
     * @param {Object} config  A hash of configuration controls for the RowType
     * 
     * @returns {Rows}  The Rows object, for chaining
     */
    Rows.defineType = function Rows_defineType( name, config ) {
      // make sure name is valid and not taken
      if(!TYPE_NAME.test(name)) {
        throw new Error("Row type name '" + name + "' is invalid (names can only contain letters, numbers, underscores, dashes, and colons)");
      } else if(name in types) {
        throw new Error("Row type '" + name + "' already exists");
      }
      
      // create the type, using properties given in config (but stripped of unnecessary properties)
      types[name] = new RowType(strip(config, ROW_CONFIG_PROPS));
      return Rows;
    };
    
    /**
     * Creates a new Row.
     * 
     * @param {String}  typeName  The name of the RowType for the new Row
     * @param {Grid}    grid      A reference to the Row's parent Grid
     * @param {String}  name      This newly created Row's name
     * @param {Object}  params    Configuration options to pass to the Row's initializer
     * @param {Object}  config    Hash of optional behaviors to override those specified by the requested type
     * 
     * @returns {Row}  A new Row
     */
    Rows.create = function Rows_create( typeName, grid, name, params, config ) {
      if(typeName !== undefined) {
        // if type name given, make sure name is valid and RowType exists
        if(!TYPE_NAME.test(typeName)) {
          throw new Error("Row type name '" + typeName + "' is invalid (names can only contain letters, numbers, underscores, dashes, and colons)");
        } else if(!(typeName in types)) {
          throw new Error("Row type '" + typeName + "' does not exist");
        }
        
        // fill in type defaults to config
        fill(strip(config, ROW_CONFIG_PROPS), types[typeName]);
      }
      
      // note the type, reference the params
      config.type = typeName;
      config.params = params;
      
      // TODO: use proper constructor values
      return new Row(grid, name, config);
    };
    
    return Rows;
  }());
  
  Column = function Column( grid, header, footer, index, name ) {
    /**
     * A reference to this Column's parent Grid.
     * @type _initOmniGrid._initGrids.Grid
     */
    this.grid = grid;
    
    /**
     * This column's index within the Grid. (0 marks the first data column; row headers aren't counted.)
     * @type Number
     */
    this.index = index;
    
    /**
     * The name of the Column.
     * @type String
     */
    this.name = name;
    
    /**
     * A list of references to the Cells falling under this Column.
     * @type _initOmniGrid._initCells.Cell[]
     */
    this.cells = [];
    
    /**
     * A reference to the header cell for this Column.
     * @type jQuery
     */
    this.header = header;
    
    /**
     * A reference to the footer cell for this Column.
     * @type jQuery
     */
    this.footer = footer;
    
    // add data object functionality
    fill(this, new DataObject());
    
    // add event managing functionality
    fill(this, new EventManager(function() {
      return this.getProxy();
    }.bind(this)));
  };
  
  Column.prototype = {
    getHeight: function Column_getHeight() {
      return this.grid.rows.length;
    },
    
    getGrid: function Column_getGrid() {
      return this.grid.getProxy();
    },
    
    getCell: function Column_getCell( name ) {
      var index;
      if( typeof name === "number" ) {
        index = name;
        if( index % 1 !== 0 || index < 0 || index >= this.cells.length ) {
          throw new Error(index + " is not a valid Cell index");
        }
      } else {
        index = this.grid.rowNames.indexOf("" + name);
        if(index === -1) {
          throw new Error("There is no row with the name '" + name + "'");
        }
      }
      
      return this.cells[index].getProxy();
    },
      
    getCells: function Column_getCells( criteria ) {
      var cells,
          c, min, max;
      
      criteria instanceof Object || (criteria = {});
      
      // filter by indices
      min = +criteria.min || undefined;
      max = +criteria.max || undefined;
      cells = this.cells.slice(min, max);
      
      // filter by column names
      if("rows" in criteria) {
        c = criteria.columns;
        if(typeof c === "string" || c instanceof String) {
          // it type is a string, make it an array
          c = [c];
        }
        
        if(c instanceof Array) {
          // if an Array, find all indices corresponding to the given names, then sort and map to those indices
          cells = c.asSet().reduce(function( prev, curr ) {
            var index = this.grid.rowNames.indexOf(name);
            if(index !== -1) {
              prev.push(index);
            }
            return prev;
          }, []).map(function( index ) {
            return cells[index];
          });
        }
      }
      
      // filter by Cell type
      if("type" in criteria) {
        c = criteria.type;
        if(typeof c === "string" || c instanceof String) {
          // it type is a string, make it an array
          c = [c];
        }
        
        if(c instanceof Array) {
          // if an array, filter out all Cell's whose type does not appear in the list
          cells = cells.filter(function( cell ) {
            return c.indexOf(cell.type) !== -1;
          });
        }
      }
      
      return cells.map(function( cell ) {
        return cell.getProxy();
      });
    },
      
    forEachCell: function Column_forEachCell( callback ) {
      if( typeof callback !== "function" ) {
        return;
      }
      
      this.cells.forEach(function( cell ) {
        callback.call(cell.getProxy());
      });
    },
      
    getValues: function Column_getValues( asHash ) {
      var ret;
      
      if( asHash ) {
        ret = {};
        this.cells.forEach(function( cell ) {
          ret[cell.getRowName()] = cell.getValue();
        });
      } else {
        ret = this.cells.map(function( cell ) {
          return cell.getValue();
        });
      }
        
        return ret;
      },
      
    getElements: function Column_getElements( doHeader, doFooter ) {
      var collection = $([]);
      
      if( arguments.length === 1 ) {
        doHeader = doFooter = !!doHeader;
      } else {
        doHeader = !!doHeader;
        doFooter = !!doFooter;
      }
      
      if( doHeader ) {
        collection = collection.add(this.header);
      }
      
      collection = this.cells.reduce(function( collection, cell ) {
        return collection.add(cell.element);
      }, collection);
      
      return doFooter ? collection.add(this.footer) : collection;
    },
    
    // get/set data
    // on/off/fire listeners/events
    
    getProxy: function Column_getProxy() {
      return proxy(this, {
        include: [ "index", "name", "header", "footer" ]
      });
    }
  };
  
  Grids = (function _initGrids() {
    var /**
         * A wrapper responsible for managing GridTypes and creating Grids.
         * @type Object
         */
        Grids = {},
        
        // GridType stuff
        GridType,
        
        /**
         * A hash of the default property values for GridTypes.
         * @type Object
         */
        GRID_TYPE_DEFAULTS = {
          init: function() {},
          rowHeaders: true,
          rowFooters: false,
          columnHeaders: true,
          columnFooters: false
        },
        
        /**
         * A list of the property names that can be used to configure a Grid.
         * @type Array
         */
        GRID_CONFIG_PROPS = Object.keys(GRID_TYPE_DEFAULTS),
        
        types = {},
        
        // utility
        createInternalTR,
        
        // Grid constructor
        Grid;
    
    /**
     * Creates a new GridType.
     * 
     * @param {Object} config
     *   A hash of properties defining the behavior of Grids of this type. The values stored here essentially
     *   act as defaults when creating Grids of this type; when Row construction actually occurs, values may
     *   be provided to override these defaults.
     *   
     *   init  Function  Called to initialize a Grid with the appropriate Rows and behaviors. Within the given
     *                   init function, 'this' refers to the table element of the new Grid. It is important to
     *                   note, however, Rows (added via a call to controls.addRow(...) - see below) are not
     *                   actually appended to this table until AFTER the init function returns. If no function
     *                   is specified for .init(), an empty one is used instead. The .init() function is passed
     *                   two arguments:
     *                   
     *                   params  (Object)
     *                     A hash of key-value pairs passed for the creation of a specific Grid. GridType 
     *                     authors can use this to provided further granularity regarding the behavior of 
     *                     specific GridTypes.
     *                                     
     *                   controls  (Object)  
     *                     A hash of functions providing various functionality with the new Grid. It always 
     *                     contains the following methods:
     *                     
     *                     addRow
     * 
     * @constructor
     */
    GridType = function GridType( config ) {
      // fill the computed values into this GridType object
      fill(this, fill(config, GRID_TYPE_DEFAULTS));
    };
    
    createInternalTR = function Grids_createInternalTR( type ) {
      var row, cells,
          header, footer;
      
      row = $("<tr />")
        .addClass(CSS(type + "Row"));

      header = $("<th />")
        .addClass(CSS("Col" + type) + " " + CSS("RowHeader"))
        .attr("scope", "row");
      
      footer = $("<td />")
        .addClass(CSS("Col" + type) + " " + CSS("RowFooter"));
      
      row.append(header)
         .append(footer);
      
      cells = [];
      
      row.header = header;
      row.footer = footer;
      row.getCells = function Grids_createInternalTR_row_getCells() {
        return cells.slice(0);
      };
      
      return {
        element: row,
        
        doHeader: function Grids_createInternalTR_doHeader( show ) {
          if( show ) {
            row.prepend(header);
          } else {
            header.detach();
          }
        },
      
        doFooter: function Grids_createInternalTR_doFooter( show ) {
          if( show ) {
            row.append(footer);
          } else {
            footer.detach();
          }
        },
      
        addCell: function Grids_createrInternalTR_addCell( index ) {
          var newCell = $("<td />").addClass(CSS("Col" + type));
          if(typeof index === "number") {
            row.insert(index + 1, newCell);
            cells = cells.slice(0, index).concat([newCell]).concat(cells.slice(index));
          } else {
            footer.before(newCell);
            cells.push(newCell);
          }
          return newCell;
        },
        
        getCells: row.getCells,
      
        removeCell: function Grids_createInteralTR_removeCell( index ) {
          row.children().eq(index + 1).remove();
          cells = cells.slice(0, index).concat(cells.slice(index + 1));
        }
      };
    };
    
    Grid = function Grid( config ) {
      var controls = {},
          head, foot, body;
      
      /**
       * The name of the GridType used to create this Grid, or undefined if this Grid was created anonymously.
       * @type String
       */
      this.type = config.type;
      
      head = $("<thead />");
      foot = $("<tfoot />");
      body = $("<tbody />");
      
      /**
       * The table element representing this Grid.
       * @type jQuery
       */
      this.element = $("<table>")
        .addClass(CSS("Grid"))
        .attr("data-og-type", this.type)
        .append(head)
        .append(foot)
        .append(body);
      
      // header and footer rows
      this.headerRow = createInternalTR("Header");
      this.footerRow = createInternalTR("Footer");
      
      // booleans to keep track of header/footer state
      this.rowHeaders = config.rowHeaders;
      this.rowFooters = config.rowFooters;
      this.colHeaders = config.columnHeaders;
      this.colFooters = config.columnFooters;
      
      // add header / footer if requested already
      if( this.colHeaders ) {
        head.append(this.headerRow.element);
      }
      
      if( this.colFooters ) {
        foot.append(this.footerRow.element);
      }
      
      /**
       * A list of this Grid's columns.
       * @type _initOmniGrid.Column[]
       */
      this.columns = [];
      
      /**
       * A list of this Grid's Columns' names (for convenience).
       * @type String[]
       */
      this.columnNames = [];
      
      /**
       * A list of this Grid's Rows.
       * @type _initOmniGrid._initRows.Row[]
       */
      this.rows = [];
      
      /**
       * A list of this Grid's Rows' names (for convenience).
       * @type String[]
       */
      this.rowNames = [];
      
      // add data functionality
      fill(this, new DataObject());
      
      // add event listener functionality
      fill(this, new EventManager(function() {
        return this.getProxy();
      }.bind(this)));
      
      // this function MUST be called before any Rows are added
      controls.setColumns = (function Grid__controls_setColumns( names ) {
        var header, footer;
        
        if(this.columns.length > 0) {
          throw new Error("Columns have already been set for this Grid");
        }
        
        if(!isArray(names) || names.length === 0) {
          throw new Error("Column names passed to controls.setColumns( ... ) must be an array with at least one element");
        }
        
        // make sure everything's a string
        names = names.map(function( name ) {
          return "" + name;
        });
        
        // no duplicates!
        if(names.length > names.asSet().length) {
          throw new Error("Duplicate columns names are not allowed. (Found duplicates in array:\n"
                  + "'" + names.join("', '") + "'.)");
        }
        
        // otherwise, all good
        this.columnNames = names.slice(0);
        names.forEach(function( name ) {
          header = this.headerRow.addCell();
          footer = this.footerRow.addCell();
          this.columns.push(new Column(this, header, footer, this.columns.length, name));
        }, this);
      }).bind(this);
      
      // since the addRow function is actually publicly visible, input validation must occur
      controls.addRow = (function Grid__controls_addRow( name, type, params, config ) {
        // make sure the initializer has already declared the number of columns
        if(this.columns.length === 0) {
          throw new Error("Grid initializer MUST make a call to controls.setColumns (to declare column names) "
                  + "BEFORE any Rows are added.");
        }
        
        // begin input validation
        if(!(typeof name === "string" || name instanceof String)) {
          // name must be a string
          throw new Error("Row name passed to addRow must be a string.");
        } else if(this.rowNames.indexOf(name) !== -1) {
          // name must be unique
          throw new Error("Row names must be unique (attempted to duplicate '" + name + "').");
        }
        
        if(arguments.length === 2) {
          // argument should be a string (type name) or an object
          if(typeof type === "string" || type instanceof String) {
            // if it's a string, treat it as a type name
            params = {};
            config = {};
          } else if(type instanceof Object) {
            // if it's an object, treat it as a configuration hash
            config = type;
            type = undefined;
            params = {};
          } else {
            throw new Error("Second argument of two passed to addRow within Grid initializer must be a string "
                    + "indicating the type to use or an object containing configuration information; instead, "
                    + "'" + type + "' was passed.");
          }
        } else if(arguments.length === 3) {
          if(!(typeof type === "string" || type instanceof String)) {
            // type must be a string
            throw new Error("Second argument of three passed to addRow within Grid initializer must be a string "
                    + "indicating the type to use.");
          } else if(!(params instanceof Object)) {
            // params must be an object
            throw new Error("Third argument of three passed to addRow within Grid initializer must be an object "
                    + "containing initialization parameters to pass to the new Cell.");
          }
          
          // everything okay, config is empty
          config = {};
        } else if(arguments.length === 4) {
          if(!(typeof type === "string" || type instanceof String)) {
            // type must be a string
            throw new Error("Second argument of four passed to addRow within Grid initializer must be a string "
                    + "indicating the type to use.");
          } else if(!(params instanceof Object)) {
            // params must be an object
            throw new Error("Third argument of four passed to addRow within Grid initializer must be an object "
                    + "containing initialization parameters to pass to the new Cell.");
          } else if(!(config instanceof Object)) {
            // config must be an object
            throw new Error("Fourth argument of four passed to addRow within Grid initializer must be an object "
                    + "containing configuration parameters to use when creating the new Cell.");
          }
          
          // everything okay
        } else {
          // invalid number of arguments, complain
          throw new Error("Function addRow within Grid initializer expects two to four arguments, "
                  + "instead got " + arguments.length + ".");
        }
        
        // if no error by now, everything's alright and arguments will have correct values
        var row = Rows.create(type, this, name, params, config);
        
        // add the Row  and its name to this Grid
        this.rows.push(row);
        this.rowNames.push(name);
        
        // add the Row's Cell's to their respective Columns
        row.cells.forEach(function( cell, index ) {
          this.columns[index].cells.push(cell);
        }, this);
        
        // append the row element to the table
        body.append(row.element);
        
        // return a proxy (for convenience)
        return row.getProxy();
      }).bind(this);
      
      // initialize the Grid
      config.init.call(this.getProxy(), config.params, controls);
    };
    
    Grid.prototype = {
      getRow: function Grid_getRow( name ) {
        var index;
        if( typeof name === "number" ) {
          index = name;
          if( index % 1 !== 0 || index < 0 || index >= this.rows.length ) {
            throw new Error(index + " is not a valid Row index");
          }
        } else {
          index = this.rowNames.indexOf("" + name);
          if(index === -1) {
            throw new Error("There is no Row with the name '" + name + "'");
          }
        }
        
        return this.rows[index].getProxy();
      },
      
      getHeaderRow: function Grid_getHeaderRow() {
        return this.headerRow.element;
      },
      
      getFooterRow: function Grid_getFooterRow() {
        return this.footerRow.element;
      },
      
      getRows: function Grid_getRows( criteria ) {
        var rows = this.rows.slice(0),
            c, min, max;
        
        criteria = criteria || {};
        
        if("columns" in criteria) {
          c = criteria.columns;
          if(typeof c === "string" || c instanceof String) {
            // it type is a string, make it an array
            c = [c];
          }
          
          if(c instanceof Array) {
            // if an Array, find all indices corresponding to the given names, then map to those indices
            rows = c.asSet().reduce(function( prev, curr ) {
              var index = this.rowNames.indexOf(curr);
              if(index !== -1 && prev.indexOf(index) === -1) {
                prev.push(index);
              }
              return prev;
            }, []).map(function( index ) {
              return rows[index];
            });
          }
        }
        
        if("type" in criteria) {
          c = criteria.type;
          if(typeof c === "string" || c instanceof String) {
            // it type is a string, make it an array
            c = [c];
          }
          
          if(c instanceof Array) {
            // if an array, filter out all Cell's whose type does not appear in the list
            rows = rows.filter(function( row ) {
              return c.indexOf(row.type) !== -1;
            });
          }
        }
        
        return rows.map(function( row ) {
          return row.getProxy();
        });
      },
      
      forEachRow: function Grid_forEachRow( callback ) {
        if( typeof callback !== "function" ) {
          return;
        }
        
        this.rows.forEach(function( row ) {
          callback.call(row.getProxy());
        });
      },
      
      getColumn: function Grid_getColumn( name ) {
        var index;
        if( typeof name === "number" ) {
          index = name;
          if( index % 1 !== 0 || index < 0 || index >= this.columns.length ) {
            throw new Error(index + " is not a valid Column index");
          }
        } else {
          index = this.columnNames.indexOf("" + name);
          if(index === -1) {
            throw new Error("There is no column with the name '" + name + "'");
          }
        }
        
        return this.columns[index].getProxy();
      },
      
      getColumns: function Grid_getColumns( criteria ) {
        var rows = this.rows.slice(0),
            c, min, max;
        
        criteria = criteria || {};
        
        if("columns" in criteria) {
          c = criteria.columns;
          if(typeof c === "string" || c instanceof String) {
            // it type is a string, make it an array
            c = [c];
          }
          
          if(c instanceof Array) {
            // if an Array, find all indices corresponding to the given names, then map to those indices
            rows = c.asSet().reduce(function( prev, curr ) {
              var index = this.rowNames.indexOf(curr);
              if(index !== -1 && prev.indexOf(index) === -1) {
                prev.push(index);
              }
              return prev;
            }, []).map(function( index ) {
              return rows[index];
            });
          }
        }
        
        return rows.map(function( row ) {
          return row.getProxy();
        });
      },
      
      forEachColumn: function Grid_forEachColumn( callback ) {
        if( typeof callback !== "function" ) {
          return;
        }
        
        this.columns.forEach(function( column ) {
          callback.call(column.getProxy());
        });
      },
      
      getCell: function Grid_getCell( row, col ) {
        return this.getRow(row).getCell(col);
      },
      
      withCell: function Grid_withCell( row, col, callback ) {
        callback.call(this.getCell(row, col));
      },
      
      getCells: function Grid_getCells( criteria ) {
        criteria = criteria || {};
        
        return this.getRows({
          rows: criteria.rows,
          type: criteria.rowType
        }).reduce(function( cellProxies, rowProxy ) {
          return cellProxies.concat(rowProxy.getCells({
            columns: criteria.columns,
            type: criteria.cellType
          }));
        }, []);
      },
      
      forEachCell: function Grid_forEachCell( callback ) {
        if(typeof callback !== "function") {
          return;
        }
        
        this.rows.forEach(function( row ) {
          row.forEachCell(callback);
        });
      },
      
      getValue: function Grid_getValue( row, col ) {
        return this.getCell(row, col).getValue();
      },
      
      getValues: function Grid_getValues( asHash, byCol ) {
        var ret,
            primary = byCol ? this.columns : this.rows;
        
        if( asHash ) {
          ret = {};
          primary.forEach(function( rowOrCol ) {
            ret[rowOrCol.name] = rowOrCol.getValues(true);
          });
        } else {
          return primary.map(function( rowOrCol ) {
            return rowOrCol.getValues(false);
          });
        }
        
        return ret;
      },
      
      getRowHeaders: function Grid_getRowHeaders() {
        return this.rows.maps(function( row ) {
          return row.header;
        });
      },
      
      getRowFooters: function Grid_getRowFooters() {
        return this.rows.map(function( row ) {
          return row.footer;
        });
      },
      
      getColumnHeaders: function Grid_getColumnHeaders() {
        return this.headerRow.getCells();
      },
      
      getColumnFooters: function Grid_getColumnFooters() {
        return this.footerRow.getCells();
      },
      
      doRowHeaders: function Grid_doRowHeaders( show ) {
        show = !!show;
        if( show !== this.rowHeaders ) {
          this.rowHeaders = show;
          this.rows.forEach(function( row ) {
            row.doHeader(show);
          });
          
          this.headerRow.doHeader(show);
          this.footerRow.doHeader(show);
        }
      },
      
      doRowFooters: function Grid_doRowFooters( show ) {
        show = !!show;
        if( show !== this.rowFooters ) {
          this.rowFooters = show;
          this.rows.forEach(function( row ) {
            row.doFooter(show);
          });
          
          this.headerRow.doFooter(show);
          this.footerRow.doFooter(show);
        }
      },
      
      doColumnHeaders: function Grid_doColumnHeaders( show ) {
        show = !!show;
        if(show !== this.colHeaders) {
          // intentional assignment
          if(this.colHeaders = show) {
            head.append(this.headerRow.element);
          } else {
            this.headerRow.detach();
          }
        }
      },
      
      doColumnFooters: function Grid_doColumnFooters( show ) {
        show = !!show;
        if(show !== this.colFooters) {
          // intentional assignment
          if(this.colFooters = show) {
            foot.append(this.footerRow.element);
          } else {
            this.footerRow.detach();
          }
        }
      },
      
      // get/set data
      // on/off/fire listeners/events
      
      getProxy: function Grid_getProxy() {
        return proxy(this, {
          include: [ "type", "element" ]
        });
      }
    };
    
    /**
     * Defines a new GridType.
     * 
     * @param {String} name    The name of the GridType to create
     * @param {Object} config  A hash of configuration controls for the GrudType
     * 
     * @returns {Grids}  The Grids object, for chaining
     */
    Grids.defineType = function Grids_defineType( name, config ) {
      // make sure name is valid and not taken
      if(!TYPE_NAME.test(name)) {
        throw new Error("Grid type name '" + name + "' is invalid (names can only contain letters, numbers, underscores, dashes, and colons)");
      } else if(name in types) {
        throw new Error("Grid type '" + name + "' already exists");
      }
      
      // create the type, using properties given in config (but stripped of unnecessary properties)
      types[name] = new GridType(strip(config, GRID_CONFIG_PROPS));
      return Grids;
    };
    
    /**
     * Creates a new Grid.
     * 
     * @param {String} typeName  The name of the GridType for the new Grid
     * @param {Object} params    Configuration options to pass to the Grid's initializer
     * @param {Object} config    Hash of optional behaviors to override those specified by the requested type
     * 
     * @returns {Grid}  A new Grid
     */
    Grids.create = function Grids_create( typeName, params, config ) {
      if(typeName !== undefined) {
        // if type name given, make sure name is valid and GridType exists
        if(!TYPE_NAME.test(typeName)) {
          throw new Error("Grid type name '" + typeName + "' is invalid (names can only contain letters, numbers, underscores, dashes, and colons)");
        } else if(!(typeName in types)) {
          throw new Error("Grid type '" + typeName + "' does not exist");
        }
        
        // fill in type defaults to config
        fill(strip(config, GRID_CONFIG_PROPS), types[typeName]);
      }
      
      // note the type, reference the params
      config.type = typeName;
      config.params = params;
      
      return new Grid(config);
    };
    
    return Grids;
  }());
  
  // define some default Cell types
  Cells.defineType("og:Default", {});
  Cells.defineType("og:Input", {
    header: false,
    init: function( params, fireUpdate ) {
      var input = $("<input />");
      
      // fire updates on input change
      input.on("oninput" in window ? "input" : "change", fireUpdate);
      
      // save a reference, append the input
      this.element._input = input;
      this.element.append(input);
    },
    initialValue: "",
    getValue: function() {
      return this._input.val();
    },
    setValue: function( newVal ) {
      newVal = "" + newVal;
      this._input.val(newVal);
      return newVal;
    }
  });
  
  // define some default RowTypes
  // og:Default allows the following params:
  //   header  String    If given, the html content to place in the header for this Row. Otherwise, no header
  //                     Cell is created.
  //   footer  Function  If given, a function to which the current values of the Row's Cells (excepting the
  //                     header and footer, if present) will be passed and which should return the value to
  //                     place in the footer. Otherwise, no footer Cell is created.
  //   initialFooter     A string containing the html content to place initially in the footer (before any
  //           String    updates have occur on the middle cells).
  //   
  //   type    String    The CellType with which the remaining spaces in the Row should be filled
  Rows.defineType("og:Default", {
    init: function( params, addCell ) {
      var cellType,
          header = params.header,
          footerFn = params.footer,
          width = this.getWidth();
      
      if( typeof footerFn === "string" ) {
        footerFn = (function( text ) { 
          return function() {
            return text;
          };
        }(footerFn));
      } else if( typeof footerFn !== "function" ) {
        footerFn = undefined;
      }
      
      if("cellType" in params) {
        cellType = params.cellType;
        if(typeof cellType !== "string") {
          throw new Error("Cell type name passed with parameters for an og:Default Row must be a string. Instead, got " + cellType + ".");
        }
      } else {
        cellType = "og:Default";
      }
      
      for(var i = 0; i < width; i++) {
        addCell(cellType);
      }
      
      if(header) {
        this.header.html(header);
      } else {
        this.header.text(this.name);
      }
      
      if(footerFn) {
        this.on("update", function() {
          this.footer.html(footerFn(this.getValues()));
        });
      }
      
      if("initialFooter" in params) {
        this.footer.html(params.initialFooter);
      }
    }
  });
  
  Grids.defineType("og:Default", {
    rowHeaders: true,
    rowFooters: true,
    columnHeaders: true,
    columnFooters: true,
    init: function( params, controls ) {
      var columns,
          rows,
          rowType,
          rowParams,
          footer;
      
      // make sure columns were given
      if( !isArray(columns = params.columns) ) {
        throw new Error("Grid type 'og:Default' requires 'columns' to be present and an array in params hash");
      }
      
      // set the columns
      controls.setColumns(columns);
      
      // rows, however, can be empty or omitted (just don't add any)
      if( !isArray(rows = params.rows) ) {
        rows = [];
      };
      
      // get the row type to use and the params to pass with initializers
      rowType = "rowType" in params ? "" + params.rowType : "og:Default";
      rowParams = params.rowParams;
      rowParams instanceof Object || (rowParams = {});
      
      // add the rows
      rows.forEach(function( name ) {
        controls.addRow(name, rowType, $.extend({}, rowParams));
      });
      
      footer = params.footer;
      if( isArray(footer) ) {
        this.getColumnFooters().forEach(function( fCell ) {
          fCell.html(footer.shift());
        });
      } else if(typeof footer === "function") {
        // data columns
        this.forEachColumn(function( column ) {
          this.footer.html(footer(this.getValues()));
        });
        
        // footer column
        this.getFooterRow().footer.html(footer(
          this.getRowFooters().map(function( fCell ) {
            return fCell.text();
          })
        ));
        
        // now listen for updates
        this.on("update", function( evt ) {
          var col = evt.source.getColumn();
          // update column footer
          col.footer.html(footer(col.getValues()));
          // update corner footer
          this.getFooterRow().footer.html(footer(
            this.getRowFooters().map(function( fCell ) {
              return fCell.text();
            })
          ));
        });
      }
    }
  });
  
  OmniGrid = function OmniGrid( type, params, config ) {
    var grid;
    
    // begin input validation
    if( arguments.length === 1 ) {
      // argument should be a string (type name) or an object
      if(typeof type === "string" || type instanceof String) {
        // if it's a string, treat it as a type name
        params = {};
        config = {};
      } else if(type instanceof Object) {
        // if it's an object, treat it as a configuration hash
        config = type;
        type = undefined;
        params = {};
      } else {
        throw new Error("Single argument passed to OmniGrid must be a string "
                + "indicating the type to use or an object containing configuration information; instead, "
                + "'" + type + "' was passed.");
      }
    } else if( arguments.length === 2 ) {
      if(!(typeof type === "string" || type instanceof String)) {
        // type must be a string
        throw new Error("First argument of two passed to OmniGrid must be a string "
                + "indicating the type to use.");
      } else if(!(params instanceof Object)) {
        // params must be an object
        throw new Error("Second argument of two passed to OmniGrid must be an object "
                + "containing initialization parameters to pass to the new Grid.");
      }
      
      // everything okay, config is empty
      config = {};
    } else if( arguments.length === 3 ) {
      if(!(typeof type === "string" || type instanceof String)) {
        // type must be a string
        throw new Error("First argument of three passed to OmniGrid must be a string "
                + "indicating the type to use.");
      } else if(!(params instanceof Object)) {
        // params must be an object
        throw new Error("Second argument of three passed to OmniGrid must be an object "
                + "containing initialization parameters to pass to the new Grid.");
      } else if(!(config instanceof Object)) {
        // config must be an object
        throw new Error("Third argument of three passed to OmniGrid must be an object "
                + "containing configuration parameters to use when creating the new Grid.");
      }
      
      // everything okay
    } else {
      // invalid number of arguments, complain
      throw new Error("Function OmniGrid expects one to three arguments, "
              + "but " + arguments.length + " were given.");
    }
    
    // make the Grid
    grid = Grids.create(type, params, config);
    
    // expose methods
    fill(this, grid.getProxy());
  };
  
  fill(OmniGrid, {
    defineGridType: Grids.defineType,
    defineRowType: Rows.defineType,
    defineCellType: Cells.defineType
  });
  
  return OmniGrid;
}());