function manage(txt) {
  var bt = document.getElementById('tog');
  var ele = document.getElementById('inputbar'); 
  if (ele.type == 'text' && ele.value == '') {
    bt.disabled = true;    // Disable the button.
    return false;
  }
  else {
    bt.disabled = false;   // Enable the button.
  }
}
function CopyToClipboard(id)
{
var r = document.createRange();
r.selectNode(document.getElementById(id));
window.getSelection().removeAllRanges();
window.getSelection().addRange(r);
document.execCommand('copy');
window.getSelection().removeAllRanges();
}