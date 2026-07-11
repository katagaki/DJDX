package com.tsubuzaki.djdxgo

import android.content.Context
import com.tsubuzaki.djdxgo.data.DJDXDatabase
import com.tsubuzaki.djdxgo.data.ddr.DDRRepository
import com.tsubuzaki.djdxgo.data.iidx.IIDXRepository
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordRepository
import com.tsubuzaki.djdxgo.data.sdvx.SDVXRepository

class AppContainer(context: Context) {
    val database = DJDXDatabase.get(context)
    val iidxRepository = IIDXRepository(database.iidxDao())
    val sdvxRepository = SDVXRepository(database.sdvxDao())
    val polarisChordRepository = PolarisChordRepository(database.polarisChordDao())
    val ddrRepository = DDRRepository(database.ddrDao())
    val externalDataDao = database.externalDataDao()
}
