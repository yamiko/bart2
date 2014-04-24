function setTextToAppear(){
    available_cpt_options = document.getElementsByTagName('li');
    for(i=0; i<available_cpt_options.length; i++){
    if (available_cpt_options[i].innerHTML.match('moh_recommend')){
      available_cpt_options[i].style.backgroundColor='#00CD66'
      available_cpt_options[i].onclick = function(){
        tmp = this.innerHTML
        this.innerHTML = this.innerHTML.replace(' <span class="moh_recommend">(MoH Recommended)</span>', "")
        updateTouchscreenInputForSelect(this);
        this.innerHTML=tmp
      }
    }
    else {
      available_cpt_options[i].onclick = function(){
	  updateTouchscreenInputForSelect(this);
        for(i=0; i<available_cpt_options.length; i++){
			if (available_cpt_options[i].innerHTML.match('moh_recommend')){
      		available_cpt_options[i].style.backgroundColor='#00CD66'
          	}
        }
      }
    }
  }

}
