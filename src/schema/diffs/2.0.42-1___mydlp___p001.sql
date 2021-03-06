ALTER TABLE RemoteStorageCIFS DROP FOREIGN KEY FK670F446848A2BFE1;
ALTER TABLE RemoteStorageDFS DROP FOREIGN KEY FK2C9D68BC48A2BFE1;
DROP TABLE RemoteStorageCIFS;
DROP TABLE RemoteStorageDFS;
CREATE TABLE RemoteStorageWindowsShare (
    password VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
    uncPath VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
    username VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
    id INT(11) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB COLLATE=utf8mb4_general_ci;
ALTER TABLE RemoteStorageWindowsShare ADD CONSTRAINT FKF67C5AF148A2BFE1 FOREIGN KEY (id) REFERENCES RemoteStorage (id) ON UPDATE NO ACTION ON DELETE NO ACTION;
