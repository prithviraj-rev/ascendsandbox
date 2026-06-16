({
                doInit : function(component, event, helper) {
                                let links = JSON.parse(component.get('v.settings'));
        component.set('v.links', links);
                }
})