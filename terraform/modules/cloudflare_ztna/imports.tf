# Import the existing WARP enrollment application into Terraform state.
import {
  to = cloudflare_zero_trust_access_application.warp_enrollment
  id = "${var.cloudflare_account_id}/${data.cloudflare_access_application.warp_enrollment.id}"
}
