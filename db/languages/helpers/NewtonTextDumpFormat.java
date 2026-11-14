package mars.mips.dump;

import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

import mars.Globals;
import mars.ProgramStatement;
import mars.mips.hardware.AddressErrorException;
import mars.mips.hardware.Memory;
import mars.util.Binary;

/** Writes the complete assembled text without SegmentWindow's column truncation. */
public final class NewtonTextDumpFormat extends AbstractDumpFormat {
    public NewtonTextDumpFormat() {
        super("Newton assembled text", "NewtonText", "Tab-separated assembled instructions", "txt");
    }

    @Override
    public void dumpMemoryRange(File file, int firstAddress, int lastAddress)
            throws AddressErrorException, IOException {
        try (BufferedWriter writer = Files.newBufferedWriter(file.toPath(), StandardCharsets.UTF_8)) {
            for (int address = firstAddress; address <= lastAddress; address += Memory.WORD_LENGTH_BYTES) {
                ProgramStatement statement = Globals.memory.getStatementNoNotify(address);
                if (statement == null) {
                    break;
                }

                String source = statement.getSource();
                writer.write(Binary.intToHexString(statement.getAddress()));
                writer.write('\t');
                writer.write(Binary.intToHexString(statement.getBinaryStatement()));
                writer.write('\t');
                writer.write(statement.getPrintableBasicAssemblyStatement().replace('\t', ' '));
                writer.write('\t');
                if (source != null && !source.isEmpty()) {
                    writer.write(Integer.toString(statement.getSourceLine()));
                }
                writer.write('\t');
                if (source != null) {
                    writer.write(source);
                }
                writer.newLine();
            }
        }
    }
}
