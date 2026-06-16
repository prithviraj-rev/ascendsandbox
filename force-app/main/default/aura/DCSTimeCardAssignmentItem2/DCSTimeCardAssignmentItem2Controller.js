({
    doInit:function(component, event, helper){
        var AssignmentLines = component.get("v.al"); 
        if (Array.isArray(AssignmentLines)){
            component.set("v.assignmentCount", AssignmentLines.length);
        } else {
            component.set("v.assignmentCount", 1);
            var ax=new Array();
            ax.push(AssignmentLines);
            component.set("v.al", ax);
        }
        var pl = component.get("v.pl");
        if(pl && pl.FeatureLines){
            component.set("v.hasFeatureLines",true); 
        }   
    },
    sendProject:function(component, event, helper){
        event.stopPropagation();
        event.preventDefault();

        console.log('SendProject');
        var setData = $A.get("e.c:DCSSetData");
        var AssignmentLines = component.get("v.al"); 
        var Assignment;
        
        if (AssignmentLines.length==1){
            Assignment = AssignmentLines[0];
        } else {
            alert("Modal selection for assignment goes here");
        }
        
        console.log('setData ');
        console.log(setData);
        console.log('AssignmentLines ');
        console.log(AssignmentLines);
        console.log('Assignment ');
        console.log(Assignment);
        console.log('isMe ');
        console.log(component.get("v.pl.isMe"));
        
        setData.setParams({"projectLineId":component.get("v.pl.Id"),
                           "projectLineName":component.get("v.pl.Name"),
                           "assignmentId":Assignment.Id,
                           "assignmentName":Assignment.Name,
                           "isMe":component.get("v.pl.isMe"),
                           "iAm":component.get("v.pl.iAm")});
        setData.fire();
    },
    handleClick:function(component, event, helper){
        var currentShowHide = component.get("v.showFeatureLines");
        component.set("v.showFeatureLines",!currentShowHide);
    }
})