import chisel3._
import net.gamebub.framework.Core
import net.gamebub.framework.interface._

class GameGearCore extends Module with Core {
  private val systemHz = 53_691_275
  private val framePeriod = 342.0 * 262.0 * 10.0 / systemHz
  private val (displayMin, displayMax) = ClocksV0.getClockDisplayHz(framePeriod)
  private val displayDivider = math.floor(1_000_000_000.0 / displayMin).toInt
  private val displayHz = 1_000_000_000 / displayDivider
  require(displayHz >= displayMin && displayHz <= displayMax,
    s"LCD clock $displayHz outside [$displayMin, $displayMax]")
  require(SdramV0.numChips >= 1, "Game Gear needs one SDRAM chip")
  val io = IO(new Bundle {
    val clocks = new ClocksV0(systemHz, displayHz, 200_000_000)
    val video = new VideoV0(160, 144, 4, 4, 4, framePeriod)
    val videoScale = new VideoScaleV0()
    val audio = new AudioV0()
    val host = new HostV0()
    val input = new InputV0()
    val sdram = new SdramV0(chips = 1)
  })
  bindExtModule("gamegear_core", io, Map("DISPLAY_DIVIDER" -> displayDivider))
}
