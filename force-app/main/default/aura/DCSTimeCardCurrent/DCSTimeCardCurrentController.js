({
	doInit : function(component, event, helper) {
        var x=document.cookie;
        if (x.includes('Billing Period')){
            component.set("v.format", "Billing Period");
            component.set("v.periodOffset", -1);
        }
		helper.getTimeCards(component);
	},

    handlePrevious : function(component, event, helper){
        component.set("v.periodOffset", component.get("v.periodOffset")-1);
        helper.getTimeCards(component);
    },

    handleNext : function(component, event, helper){
        component.set("v.periodOffset", component.get("v.periodOffset")+1);
        helper.getTimeCards(component);
    },

    handleFormat : function(component, event, helper){
        var selected = event.getSource().get("v.label");
        var format = component.get("v.format");
        if (selected != format){
            component.set("v.periodOffset", (selected == "Week")?0:-1);
            component.set("v.format", selected);
            helper.getTimeCards(component);
            helper.setCookie(component);
        }
    },

    handleSetData:function(component, event, helper){
        var tc = component.get("v.simpleTimeCard", true);
        var refresh = event.getParam("refreshCalendar");
        if (refresh != null && refresh == true){
	        helper.getTimeCards(component);
        }
    },

    handleSubmitTimesheet: function(component, event, helper) {
        helper.submitTimesheet(component, event);
    },
    
    handleResourcePlanning: function(component, event, helper) {
        helper.navigateToResourcePlanning(component, event);
    }
})