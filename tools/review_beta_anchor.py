from platform_cli import GAME, toolchain, run_process
print(run_process([toolchain()['godot'],'--path',str(GAME),'--script','res://../tools/review_beta_anchor.gd'],rendered=True,log='beta-anchor-review.log'))
