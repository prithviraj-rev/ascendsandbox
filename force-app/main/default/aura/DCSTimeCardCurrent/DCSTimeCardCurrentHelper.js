({
    getTimeCards: function(component) {
        var action = component.get("c.getTimecards");
        var offset = component.get("v.periodOffset");
        var format = component.get("v.format");

        action.setParams({"relTimePeriod":offset, "resource":null, "format":format});
        action.setCallback(this, function(a) {
            let bp = a.getReturnValue();
            component.set("v.bp", bp);
            component.set("v.buckets", bp.TimeCardDays);
            component.set("v.startDate", bp.TimeCardDays[0].dt);
            component.set("v.hasDelegated", bp.hasDelegated);
            component.set("v.totalHours", bp.total);

            if(bp.Timesheets) {
                bp.Timesheets.forEach(function(item) {
                    let startDate = new Date(item.Start_Date__c);
                    startDate = new Date(startDate.getTime() + (startDate.getTimezoneOffset() * 60000));

                    const monthName = startDate.toLocaleString('en-US', {month: 'long'});
                    item.Name = "Submit Timesheet for " + monthName;
                });
            }

            component.set("v.timesheets", bp.Timesheets);
        });

        $A.enqueueAction(action);
    },

    setCookie: function(component){
        var format = component.get("v.format");
        var d = new Date();
        d.setTime(d.getTime() + (365 * 24 * 60 * 60 * 1000));

        var expires = "expires="+d.toUTCString();
        document.cookie = "format=" + format + ";" + expires + ";path=/";
    },

    submitTimesheet: function(component, event) {
        let timesheets = component.get("v.timesheets");
        let timesheetId = (timesheets.length > 1 ? event.getParam("value") : timesheets[0].Id);
  
        var action = component.get("c.submitTimesheet");
        action.setParams({ 
            "recordId": timesheetId
        });

        action.setCallback(this, function(response) {
            if(response.getState() == 'ERROR') {
                this.showToast(response.getError()[0] ? response.getError()[0].message : 'Internal server error.', "Error", "error");
                return;
            }

            this.showToast("The Timesheet was successfully submitted.", "Information");
            component.set("v.canSubmitTimesheet", false);
        });

        $A.enqueueAction(action);
    },
    
    navigateToResourcePlanning: function(component, event) {
        let startDate = new Date(component.get("v.startDate"));
        startDate = new Date(startDate.getTime() + (startDate.getTimezoneOffset() * 60000));
        startDate.setDate(startDate.getDate() + 7);

        let url = "/lightning/n/Resource_Planning";
        url += '?c__date=' + this.getLocalDateISOString(startDate);
        url += '&c__ts=' + new Date().getTime();

        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            "url": url
        });

        urlEvent.fire();
    },

    showToast: function (message, title, type) {
        type = type || 'success';

        let toastEvent = $A.get("e.force:showToast");
        if (!toastEvent) return;

        toastEvent.setParams({
            "title": title,
            "message": message,
            "type": type
        });

        toastEvent.fire();
    },
    
    getLocalDateISOString: function(value) {
        const offset = value.getTimezoneOffset()
        value = new Date(value.getTime() - (offset*60*1000))
        return value.toISOString().split('T')[0];
    }
})