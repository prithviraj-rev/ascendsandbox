({
    doInit : function(component, event, helper) {
        helper.logTime(component, 'TimeCardDetail Init', true);
        helper.getTimecardTypes(component);
        helper.getDelegateOptions(component);
        helper.createTimecard(component);
        //component.set('v.recordId','a0R1400000QSydJEAT');
        //this.getRecord(component);
    },
    getRecord : function(component) {
        helper.logTime(component, 'TimeCardDetail getRecord');
        var tempRec = component.find("timecardRecordLDS");
        tempRec.set("v.recordId", component.get("v.remoteRecordId"));
        tempRec.reloadRecord();
        //var tc = component.get("v.simpleTimeCard",true);
        
    },
    recordUpdated : function(component, event, helper){
        console.log('setData update');
        helper.logTime(component, 'TimeCardDetail recordUpdated');
        
        var tc = component.get("v.simpleTimeCard",true);
        component.set("v.isDelegate",false);
        var delegates = component.get("v.delegateInfo");
        //console.log(delegates);  
        //console.log(tc.Resource_Delegate__c);
        if (tc.Resource_Delegate__c!=null && delegates.myResource==tc.Resource_Delegate__c){
            component.set("v.isDelegate", (tc.Resource_Id__c==tc.Resource_Delegate__c.substring(0,15)));
        }
        component.set("v.isLoading",false);
                
    },
    handleCancel : function(component,event,helper){
        helper.createTimecard(component);
        helper.refreshCalendar(component);
    },
    handleSaveAsNewTimecard : function(component, event, helper) {
        helper.logTime(component, 'TimeCardDetail handleSaveAsNewTimecard', true);
        helper.saveAsNewTimecard(component, helper);   
    },
    handleSaveTimecard : function(component, event, helper) {
        helper.logTime(component, 'TimeCardDetail handleSaveTimecard', true);
        helper.saveTimecard(component, helper);   
    },
    
    handleSetData:function(component, event, helper){
        helper.logTime(component, 'TimeCardDetail handleSetData');
        var tc = component.get("v.simpleTimeCard",true);
        var dt = event.getParam("date");
        if (dt!=null){
            tc.Date__c=dt;
            component.set("v.simpleTimeCard", tc);
        }
        if (tc.Name==null){
            tc.Name="Lightning Time Entry";
        }
        var pli = event.getParam("projectLineId");
        var rec = event.getParam("recordId");
        console.log(pli);
        console.log(rec);
        if (pli!=null){
            //console.log('Project Change');
            var isMe = event.getParam("isMe");
            //console.log('IsMe:' + isMe);
            var plo = new Object();
            plo.Id=pli;
            tc.Project_Line_Item__c=pli;
            component.set("v.projectLineName",event.getParam("projectLineName"));
            
            var alo = new Object();
            alo.Id = event.getParam("assignmentId");
            tc.Assignment__c=alo.Id;
            var aName = event.getParam("assignmentName");
            component.set("v.assignmentName",aName);
            
            if (aName.includes("Doextra Internal")){
                tc.Type__c="Non-Billable";
            } else {
                tc.Type__c="Billable";
            }
            if (isMe){
                tc.Resource_Delegate__c=null;
            } else {
                tc.Resource_Delegate__c=event.getParam("iAm");
            }
            component.set("v.simpleTimeCard", tc);
            
        } else if (rec!=null){
            component.set("v.isLoading",true);
            
            var tempRec = component.find("timecardRecordLDS");
            tempRec.set("v.recordId", rec);
            tempRec.reloadRecord();
            component.set("v.projectLineName",event.getParam("projectLineName"));
            component.set("v.assignmentName",event.getParam("assignmentName"));
            
            
            
            tc = component.get("v.simpleTimeCard",true);
            var pli = tc.Project_Line_Item__c;
            
        }
        
        
        
        document.getElementById("timecardForm").scrollIntoView();
        
        
        
    }
    
    
})