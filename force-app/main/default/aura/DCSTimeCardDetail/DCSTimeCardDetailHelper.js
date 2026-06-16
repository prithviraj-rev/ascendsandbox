({
    getDelegateOptions : function(component){
        console.log('Get Delegates');
        var action = component.get("c.getDelegateOptions");
        var that=this;
        action.setCallback(this, function(a) {
            var delegates = a.getReturnValue();
            console.log(delegates);
            component.set("v.delegateInfo", delegates);
            component.set("v.delegatePermission",delegates.delegatePermission);
            if (delegates.delegatePermission){
                var opts = new Array();
                if (delegates.options.length>0){
                    opts.push({"class":"optionClass", label:'--If assigning to another resource', value:''});
                    for (var i in delegates.options){
                        opts.push({"class":"optionClass", label:delegates.options[i].label, value:delegates.options[i].value});
                    }
                    component.find("tcDelegates").set("v.options", opts);
                    component.set("v.hasDelegates",true);
                }
                that.logTime(component, 'TimeCardDetail getDelegateOptions callback');
            }
        });
        $A.enqueueAction(action);
        
    },
    
    getTimecardTypes : function(component) {
        var action = component.get("c.getTimecardTypes");
        var that=this;
        action.setCallback(this, function(a) {
            var types = a.getReturnValue();
            //console.log(types);
            var opts = new Array();
            for (var i in types){
                opts.push({"class":"optionClass", label:types[i], value:types[i]});
            }
            component.find("tcType").set("v.options", opts);
            that.logTime(component, 'TimeCardDetail getTimecardTypes callback');
        });
        $A.enqueueAction(action);
    },
    
    createTimecard : function(component){
        var that=this;
        component.find("timecardRecordLDS").getNewRecord(
            "SFDC_Timecard__c", // sObject type (entityApiName)
            null,      // recordTypeId
            false,     // skip cache?
            $A.getCallback(function() {
                component.set("v.isLoading",false);
                var rec = component.get("v.selectedTimeCard");
                var error = component.get("v.recordError");
                if(error || (rec === null)) {
                    console.log("Error initializing record template: " + error);
                    return;
                } 
                that.logTime(component, 'TimeCardDetail createTimecard callback');
            })
        );
    },
    saveAsNewTimecard : function(component,helper){
        var tc = component.get("v.simpleTimeCard");
        var cloneTc = JSON.parse(JSON.stringify(tc));
        var that=this;
        
        component.find("timecardRecordLDS").getNewRecord(
            "SFDC_Timecard__c", // sObject type (entityApiName)
            null,      // recordTypeId
            false,     // skip cache?
            $A.getCallback(function() {
                var rec = component.get("v.selectedTimeCard");
                var error = component.get("v.recordError");
                if(error || (rec === null)) {
                    console.log("Error initializing record template: " + error);
                    return;
                } else {
                    var tcx = component.get("v.simpleTimeCard");
                    tcx.Name = cloneTc.Name;
                    tcx.Date__c = cloneTc.Date__c;
                    tcx.Hours__c = cloneTc.Hours__c;
                    tcx.Type__c = cloneTc.Type__c;
                    tcx.Assignment__c = cloneTc.Assignment__c;
                    tcx.Project_Line_Item__c = cloneTc.Project_Line_Item__c;
                    tcx.Description_of_Work__c = cloneTc.Description_of_Work__c;
                    tcx.Internal_Notes__c = cloneTc.Internal_Notes__c;
                    component.set("v.simpleTimeCard", tcx);
                    
                    helper.saveTimecard(component, helper);
                    that.logTime(component, 'TimeCardDetail saveAsNewTimecard callback');
                }
            })
        );
    },
    validateTimecard : function(component){
        var bValid = true;
        var tcHours = component.find("tcHours");
        var hours = tcHours.get("v.value");
        if (hours==null || isNaN(hours) || hours<0){
            tcHours.set("v.errors", [{message:"Hours should be a number"}]);
            bValid = false;
        } else {
            tcHours.set("v.errors",null);
        }
        var tcDate = component.find("tcDateB");
        var dateValue = tcDate.get("v.value");
        if (dateValue==null || isNaN(new Date(dateValue))){
            tcDate.set("v.errors", [{message:"Please enter a date or select one in the calendar section."}]);
            bValid = false;
        } else {
            tcDate.set("v.errors",null);
        }
        
        var tcDoW = component.find("tcDoW");
        var dow = tcDoW.get("v.value");
        if (dow==null || dow==''){
            tcDoW.set("v.errors", [{message:"Please enter a description of work."}]);
            bValid = false;
        } else {
            tcDoW.set("v.errors",null);
        }
        
        var tcType = component.find("tcType");
        var worktype = tcType.get("v.value");
        if (worktype==null || worktype==''){
            tcType.set("v.errors", [{message:"Please select a type."}]);
            bValid = false;
        } else {
            tcType.set("v.errors",null);
        }
        
        var tc = component.get("v.simpleTimeCard",true);
        var tcPLI = component.find("tcPLI");
        var project = tc.Project_Line_Item__c
        if (project==null || project==''){
            tcPLI.set("v.errors", [{message:"Please make a selection from the Recent or All projects lists."}]);
            bValid = false;
        } else {
            tcPLI.set("v.errors",null);
        }
        
        
        return bValid;
    },
    refreshCalendar:function(component){
        var setData = $A.get("e.c:DCSSetData");
        setData.setParams({"refreshCalendar":true});
        setData.fire();
        window.scrollTo(0, 0);
    },
    saveTimecard : function(component, helper) {
        var that=this;
        var valid = helper.validateTimecard(component);
        if (valid){
            component.set("v.isLoading",true);
            
            var tc = component.get("v.simpleTimeCard");
            var ax = tc.Assignment__r;
            var px = tc.Project_Line_Item__r;
            if (tc.Id==null){
                //    tc.Assignment__r=null;
                //    tc.Project_Line_Item__r=null;
            }
            component.set("v.projectLineName","");
            component.set("v.assignmentName","");
            component.set("v.simpleTimeCard",tc);
            
            component.find("timecardRecordLDS").saveRecord(function(saveResult) { 
                if (saveResult.state === "SUCCESS" || saveResult.state === "DRAFT") {
                    // Success! Prepare a toast UI message
                    var resultsToast = $A.get("e.force:showToast");
                    resultsToast.setParams({
                        "title": "Timecard Saved",
                        "message": "Timecard Saved."
                    });
                    resultsToast.fire();
                    // Reload the view so components not using force:recordData
                    // are updated
                    //$A.get("e.force:refreshView").fire();
                    helper.createTimecard(component);
                    helper.refreshCalendar(component);
                    component.set("v.isLoading",false);
                    
                } else if (saveResult.state === "INCOMPLETE") {
                    console.log("User is offline, device doesn't support drafts.");
                }  else if (saveResult.state === "ERROR") {
                        var errMsg = "";
                        // saveResult.error is an array of errors, 
                        // so collect all errors into one message
                        for (var i = 0; i < saveResult.error.length; i++) {
                            errMsg += saveResult.error[i].message + "\n";
                        }
                        component.set("v.recordError", errMsg);
                        console.log(JSON.stringify(saveResult));
                } else {
                    component.set("v.recordError", "No Error");
                }
                that.logTime(component, 'TimeCardDetail saveTimecard callback');

            });		
        }
    },
    logTime:function(component, message, start){
        var t = component.get("v.timeCheck");
        var tx = (new Date()).getTime();
        var d = 0; 
        if (start!=true){
            d = tx-t;
        }
        console.log('TC ' + tx + ' (' + d + ') ' + message);
        component.set("v.timeCheck", tx);
        
    }
    
    
})