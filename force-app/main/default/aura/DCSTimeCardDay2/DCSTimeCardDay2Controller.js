({
    sendDate:function(component, event, helper){
        var setData = $A.get("e.c:DCSSetData");
        setData.setParams({"date":component.get("v.day.dt")});
        setData.fire();
    }


})