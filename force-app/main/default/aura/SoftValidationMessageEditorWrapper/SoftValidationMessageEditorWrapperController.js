({
  makeUnsavedChanges: function(cmp, evt, helper) {
    let unsavedChanges = cmp.find('unsavedChanges');
    unsavedChanges.setUnsavedChanges(true, {label: 'Soft Validation Message Configuration'});
  },
  
  clearUnsavedChanges: function(cmp, evt, helper) {
    let unsavedChanges = cmp.find('unsavedChanges');
    unsavedChanges.setUnsavedChanges(false);
  },
  
  handleSave: function(cmp, evt, helper) {
    cmp.find('soft-validation-msg-editor-lwc').save();
  },
  
  handleDiscard: function(cmp, evt, helper) {
    let unsavedChanges = cmp.find('unsavedChanges');
    unsavedChanges.setUnsavedChanges(false);
  }
});