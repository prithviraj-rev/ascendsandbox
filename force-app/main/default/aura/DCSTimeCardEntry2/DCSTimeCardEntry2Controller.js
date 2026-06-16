({
    sendRecord:function(component, event, helper){
        var setData = $A.get("e.c:DCSSetData");
        setData.setParams({"recordId":component.get("v.entry.Id"),
                           "projectLineName":component.get("v.entry.Project_Line_Item__r.Name"),
                           "assignmentName":component.get("v.entry.Assignment__r.Name")
                          });
        setData.fire();
    }})