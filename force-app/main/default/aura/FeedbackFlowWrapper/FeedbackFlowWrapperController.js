({
    doInit : function(component, event, helper) {
        var flow = component.find("feedbackFlow");
        var inputVariables = [];
        flow.startFlow(component.get("v.flowApiName"), inputVariables);
    },
    handleStatusChange : function(component, event, helper) {
        var status = event.getParam("status");
        if (status === "FINISHED" || status === "FINISHED_SCREEN") {
            var currentUrl = window.location.href;
            if (currentUrl.indexOf('my.site.com') > -1) {
                window.location.href = '/Contractors/s/feedback/Feedback__c/list';
            } else {
                window.location.href = "/lightning/o/Feedback__c/list";
            }
        }
    }
})